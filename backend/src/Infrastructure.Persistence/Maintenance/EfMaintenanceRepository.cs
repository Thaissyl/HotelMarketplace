using System.Data;
using HotelMarketplace.Application.Maintenance;
using HotelMarketplace.Application.HotelManagement.Dtos;
using HotelMarketplace.Application.Maintenance.Dtos;
using HotelMarketplace.Application.Maintenance.Requests;
using HotelMarketplace.Domain.Entities;
using HotelMarketplace.Domain.Enums;
using HotelMarketplace.Infrastructure.Persistence.Common;
using HotelMarketplace.SharedKernel.Time;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;

namespace HotelMarketplace.Infrastructure.Persistence.Maintenance;

internal sealed class EfMaintenanceRepository : IMaintenanceRepository
{
    private readonly HotelMarketplaceDbContext _dbContext;
    private readonly IDateTimeProvider _dateTimeProvider;

    public EfMaintenanceRepository(HotelMarketplaceDbContext dbContext, IDateTimeProvider dateTimeProvider)
    {
        _dbContext = dbContext;
        _dateTimeProvider = dateTimeProvider;
    }

    public async Task<IReadOnlyCollection<PhysicalRoomDto>> GetRoomsAsync(
        Guid hotelId,
        Guid? roomTypeId,
        CancellationToken cancellationToken)
    {
        IQueryable<PhysicalRoom> query = _dbContext.PhysicalRooms
            .IgnoreQueryFilters()
            .AsNoTracking()
            .Where(room => room.HotelId == hotelId);

        if (roomTypeId.HasValue)
        {
            query = query.Where(room => room.RoomTypeId == roomTypeId.Value);
        }

        return await query
            .OrderBy(room => room.RoomNumber)
            .Select(room => new PhysicalRoomDto(
                room.Id,
                room.HotelId,
                room.RoomTypeId,
                room.RoomNumber,
                room.Floor,
                room.Notes,
                room.Status))
            .ToArrayAsync(cancellationToken);
    }

    public async Task<IReadOnlyCollection<MaintenanceRequestDto>> GetRequestsAsync(
        Guid hotelId,
        MaintenanceRequestQueryRequest request,
        CancellationToken cancellationToken)
    {
        IQueryable<MaintenanceRequest> query = _dbContext.MaintenanceRequests
            .IgnoreQueryFilters()
            .AsNoTracking()
            .Where(maintenanceRequest => maintenanceRequest.HotelId == hotelId);

        if (request.Status.HasValue)
        {
            query = query.Where(maintenanceRequest => maintenanceRequest.Status == request.Status.Value);
        }

        if (request.AssignedToUserAccountId.HasValue)
        {
            query = query.Where(maintenanceRequest => maintenanceRequest.AssignedToUserAccountId == request.AssignedToUserAccountId.Value);
        }

        return await (
            from maintenanceRequest in query
            join room in _dbContext.PhysicalRooms.IgnoreQueryFilters().AsNoTracking()
                on maintenanceRequest.PhysicalRoomId equals room.Id
            orderby maintenanceRequest.CreatedAtUtc descending
            select new MaintenanceRequestDto(
                maintenanceRequest.Id,
                maintenanceRequest.HotelId,
                maintenanceRequest.PhysicalRoomId,
                room.RoomNumber,
                maintenanceRequest.ReportedByUserAccountId,
                maintenanceRequest.AssignedToUserAccountId,
                maintenanceRequest.Description,
                maintenanceRequest.Severity,
                maintenanceRequest.Status,
                room.Status,
                maintenanceRequest.CreatedAtUtc,
                maintenanceRequest.ResolvedAtUtc,
                maintenanceRequest.ResolutionNote))
            .ToListAsync(cancellationToken);
    }

    public async Task<MaintenanceRequestPersistenceResult> ReportRoomIssueAsync(
        Guid hotelId,
        Guid actorUserAccountId,
        ReportRoomIssueRequest request,
        CancellationToken cancellationToken)
    {
        IExecutionStrategy executionStrategy = _dbContext.Database.CreateExecutionStrategy();

        return await executionStrategy.ExecuteAsync(async () =>
        {
            await using IDbContextTransaction transaction = await _dbContext.Database.BeginTransactionAsync(
                IsolationLevel.Serializable,
                cancellationToken);

            bool roomLockAcquired = await SqlApplicationLock.AcquireRoomLocksAsync(
                _dbContext,
                hotelId,
                new[] { request.PhysicalRoomId },
                cancellationToken);
            if (!roomLockAcquired)
            {
                await transaction.RollbackAsync(cancellationToken);
                return MaintenanceRequestPersistenceResult.Failure(MaintenancePersistenceStatus.LockUnavailable);
            }

            PhysicalRoom? room = await _dbContext.PhysicalRooms
                .IgnoreQueryFilters()
                .FirstOrDefaultAsync(entity => entity.Id == request.PhysicalRoomId && entity.HotelId == hotelId, cancellationToken);

            if (room is null)
            {
                await transaction.RollbackAsync(cancellationToken);
                return MaintenanceRequestPersistenceResult.Failure(MaintenancePersistenceStatus.RoomNotFound);
            }

            MaintenanceRequest maintenanceRequest = new(
                Guid.NewGuid(),
                hotelId,
                room.Id,
                actorUserAccountId,
                request.Description,
                request.Severity);

            try
            {
                RoomOperationalStatus oldStatus = room.Status;
                room.BlockForMaintenance(request.TargetRoomStatus);

                await _dbContext.RoomStatusHistories.AddAsync(
                    new RoomStatusHistory(Guid.NewGuid(), hotelId, room.Id, oldStatus, room.Status, actorUserAccountId),
                    cancellationToken);
            }
            catch (SharedKernel.Exceptions.DomainException)
            {
                await transaction.RollbackAsync(cancellationToken);
                return MaintenanceRequestPersistenceResult.Failure(MaintenancePersistenceStatus.InvalidRoomStatus);
            }

            await _dbContext.MaintenanceRequests.AddAsync(maintenanceRequest, cancellationToken);
            await _dbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);

            return MaintenanceRequestPersistenceResult.Success(await ToDtoAsync(maintenanceRequest.Id, cancellationToken));
        });
    }

    public async Task<MaintenanceRequestPersistenceResult> UpdateRequestStatusAsync(
        Guid hotelId,
        Guid requestId,
        Guid actorUserAccountId,
        bool canOverrideAssignee,
        UpdateMaintenanceRequestStatusRequest request,
        CancellationToken cancellationToken)
    {
        IExecutionStrategy executionStrategy = _dbContext.Database.CreateExecutionStrategy();

        return await executionStrategy.ExecuteAsync(async () =>
        {
            await using IDbContextTransaction transaction = await _dbContext.Database.BeginTransactionAsync(
                IsolationLevel.Serializable,
                cancellationToken);

            bool requestLockAcquired = await SqlApplicationLock.AcquireExclusiveAsync(
                _dbContext,
                $"maintenance:request:{hotelId:N}:{requestId:N}",
                cancellationToken);
            if (!requestLockAcquired)
            {
                await transaction.RollbackAsync(cancellationToken);
                return MaintenanceRequestPersistenceResult.Failure(MaintenancePersistenceStatus.LockUnavailable);
            }

            MaintenanceRequest? maintenanceRequest = await _dbContext.MaintenanceRequests
                .IgnoreQueryFilters()
                .FirstOrDefaultAsync(entity => entity.Id == requestId && entity.HotelId == hotelId, cancellationToken);

            if (maintenanceRequest is null)
            {
                await transaction.RollbackAsync(cancellationToken);
                return MaintenanceRequestPersistenceResult.Failure(MaintenancePersistenceStatus.RequestNotFound);
            }

            bool roomLockAcquired = await SqlApplicationLock.AcquireRoomLocksAsync(
                _dbContext,
                hotelId,
                new[] { maintenanceRequest.PhysicalRoomId },
                cancellationToken);
            if (!roomLockAcquired)
            {
                await transaction.RollbackAsync(cancellationToken);
                return MaintenanceRequestPersistenceResult.Failure(MaintenancePersistenceStatus.LockUnavailable);
            }

            PhysicalRoom? room = await _dbContext.PhysicalRooms
                .IgnoreQueryFilters()
                .FirstOrDefaultAsync(entity => entity.Id == maintenanceRequest.PhysicalRoomId && entity.HotelId == hotelId, cancellationToken);

            if (room is null)
            {
                await transaction.RollbackAsync(cancellationToken);
                return MaintenanceRequestPersistenceResult.Failure(MaintenancePersistenceStatus.RoomNotFound);
            }

            try
            {
                if (request.Status == MaintenanceStatus.InProgress)
                {
                    maintenanceRequest.Start(actorUserAccountId, canOverrideAssignee);
                }
                else if (request.Status == MaintenanceStatus.Resolved)
                {
                    RoomOperationalStatus oldStatus = room.Status;
                    bool requiresRoomInspection = await _dbContext.HotelProperties
                        .IgnoreQueryFilters()
                        .AsNoTracking()
                        .Where(hotel => hotel.Id == hotelId)
                        .Select(hotel => hotel.RequiresRoomInspection)
                        .SingleAsync(cancellationToken);
                    maintenanceRequest.Resolve(
                        actorUserAccountId,
                        canOverrideAssignee,
                        request.ResolutionNote!,
                        _dateTimeProvider.UtcNow);
                    room.CompleteMaintenance(requiresRoomInspection);

                    await _dbContext.RoomStatusHistories.AddAsync(
                        new RoomStatusHistory(Guid.NewGuid(), hotelId, room.Id, oldStatus, room.Status, actorUserAccountId),
                        cancellationToken);

                    if (!requiresRoomInspection)
                    {
                        bool hasOpenCleaningTask = await _dbContext.HousekeepingTasks
                            .IgnoreQueryFilters()
                            .AsNoTracking()
                            .AnyAsync(task => task.PhysicalRoomId == room.Id &&
                                task.Status != HousekeepingTaskStatus.Completed &&
                                task.Status != HousekeepingTaskStatus.Cancelled,
                                cancellationToken);
                        if (!hasOpenCleaningTask)
                        {
                            await _dbContext.HousekeepingTasks.AddAsync(
                                new HousekeepingTask(Guid.NewGuid(), hotelId, room.Id, "PostMaintenanceCleaning"),
                                cancellationToken);
                        }
                    }
                }
                else if (request.Status == MaintenanceStatus.Released)
                {
                    RoomOperationalStatus oldStatus = room.Status;
                    if (room.Status == RoomOperationalStatus.InspectionRequired)
                    {
                        room.CompleteInspection();
                        await _dbContext.RoomStatusHistories.AddAsync(
                            new RoomStatusHistory(Guid.NewGuid(), hotelId, room.Id, oldStatus, room.Status, actorUserAccountId),
                            cancellationToken);
                    }
                    else if (room.Status != RoomOperationalStatus.Available)
                    {
                        await transaction.RollbackAsync(cancellationToken);
                        return MaintenanceRequestPersistenceResult.Failure(MaintenancePersistenceStatus.InvalidRoomStatus);
                    }

                    maintenanceRequest.Release();
                }
                else
                {
                    await transaction.RollbackAsync(cancellationToken);
                    return MaintenanceRequestPersistenceResult.Failure(MaintenancePersistenceStatus.InvalidTransition);
                }
            }
            catch (SharedKernel.Exceptions.DomainException exception)
            {
                await transaction.RollbackAsync(cancellationToken);
                return MaintenanceRequestPersistenceResult.Failure(
                    exception.Code == "MaintenanceRequest.AssigneeOwnershipConflict"
                        ? MaintenancePersistenceStatus.AssigneeOwnershipConflict
                        : MaintenancePersistenceStatus.InvalidTransition);
            }

            await _dbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);

            return MaintenanceRequestPersistenceResult.Success(await ToDtoAsync(maintenanceRequest.Id, cancellationToken));
        });
    }

    public async Task<MaintenanceRequestPersistenceResult> AssignRequestAsync(
        Guid hotelId,
        Guid requestId,
        Guid assignedToUserAccountId,
        CancellationToken cancellationToken)
    {
        IExecutionStrategy executionStrategy = _dbContext.Database.CreateExecutionStrategy();

        return await executionStrategy.ExecuteAsync(async () =>
        {
            await using IDbContextTransaction transaction = await _dbContext.Database.BeginTransactionAsync(
                IsolationLevel.Serializable,
                cancellationToken);

            bool requestLockAcquired = await SqlApplicationLock.AcquireExclusiveAsync(
                _dbContext,
                $"maintenance:request:{hotelId:N}:{requestId:N}",
                cancellationToken);
            if (!requestLockAcquired)
            {
                await transaction.RollbackAsync(cancellationToken);
                return MaintenanceRequestPersistenceResult.Failure(MaintenancePersistenceStatus.LockUnavailable);
            }

            bool assigneeExists = await (
                from assignment in _dbContext.HotelStaffAssignments.IgnoreQueryFilters().AsNoTracking()
                join role in _dbContext.UserRoles.AsNoTracking()
                    on assignment.RoleId equals role.Id
                where assignment.HotelId == hotelId
                    && assignment.UserAccountId == assignedToUserAccountId
                    && assignment.IsActive
                    && role.Code == nameof(UserRoleCode.MaintenanceStaff)
                select assignment.Id)
                .AnyAsync(cancellationToken);

            if (!assigneeExists)
            {
                await transaction.RollbackAsync(cancellationToken);
                return MaintenanceRequestPersistenceResult.Failure(MaintenancePersistenceStatus.AssigneeNotFound);
            }

            MaintenanceRequest? maintenanceRequest = await _dbContext.MaintenanceRequests
                .IgnoreQueryFilters()
                .FirstOrDefaultAsync(entity => entity.Id == requestId && entity.HotelId == hotelId, cancellationToken);

            if (maintenanceRequest is null)
            {
                await transaction.RollbackAsync(cancellationToken);
                return MaintenanceRequestPersistenceResult.Failure(MaintenancePersistenceStatus.RequestNotFound);
            }

            try
            {
                maintenanceRequest.Assign(assignedToUserAccountId);
            }
            catch (SharedKernel.Exceptions.DomainException)
            {
                await transaction.RollbackAsync(cancellationToken);
                return MaintenanceRequestPersistenceResult.Failure(MaintenancePersistenceStatus.InvalidTransition);
            }

            await _dbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);

            return MaintenanceRequestPersistenceResult.Success(await ToDtoAsync(maintenanceRequest.Id, cancellationToken));
        });
    }

    private async Task<MaintenanceRequestDto> ToDtoAsync(
        Guid requestId,
        CancellationToken cancellationToken)
    {
        return await (
            from maintenanceRequest in _dbContext.MaintenanceRequests.IgnoreQueryFilters().AsNoTracking()
            join room in _dbContext.PhysicalRooms.IgnoreQueryFilters().AsNoTracking()
                on maintenanceRequest.PhysicalRoomId equals room.Id
            where maintenanceRequest.Id == requestId
            select new MaintenanceRequestDto(
                maintenanceRequest.Id,
                maintenanceRequest.HotelId,
                maintenanceRequest.PhysicalRoomId,
                room.RoomNumber,
                maintenanceRequest.ReportedByUserAccountId,
                maintenanceRequest.AssignedToUserAccountId,
                maintenanceRequest.Description,
                maintenanceRequest.Severity,
                maintenanceRequest.Status,
                room.Status,
                maintenanceRequest.CreatedAtUtc,
                maintenanceRequest.ResolvedAtUtc,
                maintenanceRequest.ResolutionNote))
            .FirstAsync(cancellationToken);
    }

}
