using System.Data;
using HotelMarketplace.Application.Housekeeping;
using HotelMarketplace.Application.Housekeeping.Dtos;
using HotelMarketplace.Application.Housekeeping.Requests;
using HotelMarketplace.Domain.Entities;
using HotelMarketplace.Domain.Enums;
using HotelMarketplace.Infrastructure.Persistence.Common;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;

namespace HotelMarketplace.Infrastructure.Persistence.Housekeeping;

internal sealed class EfHousekeepingRepository : IHousekeepingRepository
{
    private readonly HotelMarketplaceDbContext _dbContext;

    public EfHousekeepingRepository(HotelMarketplaceDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    public async Task<IReadOnlyCollection<HousekeepingTaskDto>> GetTasksAsync(
        Guid hotelId,
        HousekeepingTaskQueryRequest request,
        CancellationToken cancellationToken)
    {
        IQueryable<HousekeepingTask> query = _dbContext.HousekeepingTasks
            .IgnoreQueryFilters()
            .AsNoTracking()
            .Where(task => task.HotelId == hotelId);

        if (request.Status.HasValue)
        {
            query = query.Where(task => task.Status == request.Status.Value);
        }

        if (request.AssignedToUserAccountId.HasValue)
        {
            query = query.Where(task => task.AssignedToUserAccountId == request.AssignedToUserAccountId.Value);
        }

        return await (
            from task in query
            join room in _dbContext.PhysicalRooms.IgnoreQueryFilters().AsNoTracking()
                on task.PhysicalRoomId equals room.Id
            orderby task.CreatedAtUtc descending
            select new HousekeepingTaskDto(
                task.Id,
                task.HotelId,
                task.PhysicalRoomId,
                room.RoomNumber,
                task.BookingId,
                task.AssignedToUserAccountId,
                task.TaskType,
                task.Status,
                room.Status,
                task.CreatedAtUtc))
            .ToListAsync(cancellationToken);
    }

    public async Task<HousekeepingTaskUpdateResult> UpdateTaskStatusAsync(
        Guid hotelId,
        Guid taskId,
        Guid actorUserAccountId,
        HousekeepingTaskStatus targetStatus,
        CancellationToken cancellationToken)
    {
        IExecutionStrategy executionStrategy = _dbContext.Database.CreateExecutionStrategy();

        return await executionStrategy.ExecuteAsync(async () =>
        {
            await using IDbContextTransaction transaction = await _dbContext.Database.BeginTransactionAsync(
                IsolationLevel.Serializable,
                cancellationToken);

            bool taskLockAcquired = await SqlApplicationLock.AcquireExclusiveAsync(
                _dbContext,
                $"housekeeping:{hotelId:N}:{taskId:N}",
                cancellationToken);
            if (!taskLockAcquired)
            {
                await transaction.RollbackAsync(cancellationToken);
                return HousekeepingTaskUpdateResult.Failure(HousekeepingPersistenceStatus.LockUnavailable);
            }

            HousekeepingTask? task = await _dbContext.HousekeepingTasks
                .IgnoreQueryFilters()
                .FirstOrDefaultAsync(entity => entity.Id == taskId && entity.HotelId == hotelId, cancellationToken);

            if (task is null)
            {
                await transaction.RollbackAsync(cancellationToken);
                return HousekeepingTaskUpdateResult.Failure(HousekeepingPersistenceStatus.TaskNotFound);
            }

            bool roomLockAcquired = await SqlApplicationLock.AcquireRoomLocksAsync(
                _dbContext,
                hotelId,
                new[] { task.PhysicalRoomId },
                cancellationToken);
            if (!roomLockAcquired)
            {
                await transaction.RollbackAsync(cancellationToken);
                return HousekeepingTaskUpdateResult.Failure(HousekeepingPersistenceStatus.LockUnavailable);
            }

            PhysicalRoom? room = await _dbContext.PhysicalRooms
                .IgnoreQueryFilters()
                .FirstOrDefaultAsync(entity => entity.Id == task.PhysicalRoomId && entity.HotelId == hotelId, cancellationToken);

            if (room is null)
            {
                await transaction.RollbackAsync(cancellationToken);
                return HousekeepingTaskUpdateResult.Failure(HousekeepingPersistenceStatus.RoomNotFound);
            }

            bool requiresRoomInspection = await _dbContext.HotelProperties
                .IgnoreQueryFilters()
                .AsNoTracking()
                .Where(hotel => hotel.Id == hotelId)
                .Select(hotel => hotel.RequiresRoomInspection)
                .SingleAsync(cancellationToken);

            try
            {
                RoomOperationalStatus oldStatus = room.Status;

                if (targetStatus == HousekeepingTaskStatus.InProgress)
                {
                    task.Start(actorUserAccountId);
                    room.StartHousekeeping();
                }
                else if (targetStatus == HousekeepingTaskStatus.Completed)
                {
                    task.CompleteCleaning(requiresRoomInspection);
                    room.CompleteHousekeeping(requiresRoomInspection);
                }
                else
                {
                    await transaction.RollbackAsync(cancellationToken);
                    return HousekeepingTaskUpdateResult.Failure(HousekeepingPersistenceStatus.InvalidTransition);
                }

                if (oldStatus != room.Status)
                {
                    await _dbContext.RoomStatusHistories.AddAsync(
                        new RoomStatusHistory(Guid.NewGuid(), hotelId, room.Id, oldStatus, room.Status, actorUserAccountId),
                        cancellationToken);
                }
            }
            catch (SharedKernel.Exceptions.DomainException)
            {
                await transaction.RollbackAsync(cancellationToken);
                return HousekeepingTaskUpdateResult.Failure(HousekeepingPersistenceStatus.InvalidTransition);
            }

            await _dbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);

            return HousekeepingTaskUpdateResult.Success(await ToDtoAsync(task.Id, cancellationToken));
        });
    }

    public async Task<HousekeepingTaskUpdateResult> CompleteInspectionAsync(
        Guid hotelId,
        Guid taskId,
        Guid actorUserAccountId,
        CancellationToken cancellationToken)
    {
        IExecutionStrategy executionStrategy = _dbContext.Database.CreateExecutionStrategy();

        return await executionStrategy.ExecuteAsync(async () =>
        {
            await using IDbContextTransaction transaction = await _dbContext.Database.BeginTransactionAsync(
                IsolationLevel.Serializable,
                cancellationToken);

            if (!await SqlApplicationLock.AcquireExclusiveAsync(_dbContext, $"housekeeping:{hotelId:N}:{taskId:N}", cancellationToken))
            {
                await transaction.RollbackAsync(cancellationToken);
                return HousekeepingTaskUpdateResult.Failure(HousekeepingPersistenceStatus.LockUnavailable);
            }

            HousekeepingTask? task = await _dbContext.HousekeepingTasks
                .IgnoreQueryFilters()
                .FirstOrDefaultAsync(entity => entity.Id == taskId && entity.HotelId == hotelId, cancellationToken);
            if (task is null)
            {
                await transaction.RollbackAsync(cancellationToken);
                return HousekeepingTaskUpdateResult.Failure(HousekeepingPersistenceStatus.TaskNotFound);
            }

            if (!await SqlApplicationLock.AcquireRoomLocksAsync(_dbContext, hotelId, new[] { task.PhysicalRoomId }, cancellationToken))
            {
                await transaction.RollbackAsync(cancellationToken);
                return HousekeepingTaskUpdateResult.Failure(HousekeepingPersistenceStatus.LockUnavailable);
            }

            PhysicalRoom? room = await _dbContext.PhysicalRooms
                .IgnoreQueryFilters()
                .FirstOrDefaultAsync(entity => entity.Id == task.PhysicalRoomId && entity.HotelId == hotelId, cancellationToken);
            if (room is null)
            {
                await transaction.RollbackAsync(cancellationToken);
                return HousekeepingTaskUpdateResult.Failure(HousekeepingPersistenceStatus.RoomNotFound);
            }

            try
            {
                RoomOperationalStatus oldStatus = room.Status;
                task.CompleteInspection();
                room.CompleteInspection();
                await _dbContext.RoomStatusHistories.AddAsync(
                    new RoomStatusHistory(Guid.NewGuid(), hotelId, room.Id, oldStatus, room.Status, actorUserAccountId),
                    cancellationToken);
            }
            catch (SharedKernel.Exceptions.DomainException)
            {
                await transaction.RollbackAsync(cancellationToken);
                return HousekeepingTaskUpdateResult.Failure(HousekeepingPersistenceStatus.InvalidTransition);
            }

            await _dbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);
            return HousekeepingTaskUpdateResult.Success(await ToDtoAsync(task.Id, cancellationToken));
        });
    }

    public async Task<HousekeepingTaskUpdateResult> AssignTaskAsync(
        Guid hotelId,
        Guid taskId,
        Guid assignedToUserAccountId,
        CancellationToken cancellationToken)
    {
        IExecutionStrategy executionStrategy = _dbContext.Database.CreateExecutionStrategy();

        return await executionStrategy.ExecuteAsync(async () =>
        {
            await using IDbContextTransaction transaction = await _dbContext.Database.BeginTransactionAsync(
                IsolationLevel.Serializable,
                cancellationToken);

            bool taskLockAcquired = await SqlApplicationLock.AcquireExclusiveAsync(
                _dbContext,
                $"housekeeping:{hotelId:N}:{taskId:N}",
                cancellationToken);
            if (!taskLockAcquired)
            {
                await transaction.RollbackAsync(cancellationToken);
                return HousekeepingTaskUpdateResult.Failure(HousekeepingPersistenceStatus.LockUnavailable);
            }

            bool assigneeExists = await (
                from assignment in _dbContext.HotelStaffAssignments.IgnoreQueryFilters().AsNoTracking()
                join role in _dbContext.UserRoles.AsNoTracking()
                    on assignment.RoleId equals role.Id
                where assignment.HotelId == hotelId
                    && assignment.UserAccountId == assignedToUserAccountId
                    && assignment.IsActive
                    && role.Code == nameof(UserRoleCode.HousekeepingStaff)
                select assignment.Id)
                .AnyAsync(cancellationToken);

            if (!assigneeExists)
            {
                await transaction.RollbackAsync(cancellationToken);
                return HousekeepingTaskUpdateResult.Failure(HousekeepingPersistenceStatus.AssigneeNotFound);
            }

            HousekeepingTask? task = await _dbContext.HousekeepingTasks
                .IgnoreQueryFilters()
                .FirstOrDefaultAsync(entity => entity.Id == taskId && entity.HotelId == hotelId, cancellationToken);

            if (task is null)
            {
                await transaction.RollbackAsync(cancellationToken);
                return HousekeepingTaskUpdateResult.Failure(HousekeepingPersistenceStatus.TaskNotFound);
            }

            try
            {
                task.Assign(assignedToUserAccountId);
            }
            catch (SharedKernel.Exceptions.DomainException)
            {
                await transaction.RollbackAsync(cancellationToken);
                return HousekeepingTaskUpdateResult.Failure(HousekeepingPersistenceStatus.InvalidTransition);
            }

            await _dbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);

            return HousekeepingTaskUpdateResult.Success(await ToDtoAsync(task.Id, cancellationToken));
        });
    }

    private async Task<HousekeepingTaskDto> ToDtoAsync(
        Guid taskId,
        CancellationToken cancellationToken)
    {
        return await (
            from task in _dbContext.HousekeepingTasks.IgnoreQueryFilters().AsNoTracking()
            join room in _dbContext.PhysicalRooms.IgnoreQueryFilters().AsNoTracking()
                on task.PhysicalRoomId equals room.Id
            where task.Id == taskId
            select new HousekeepingTaskDto(
                task.Id,
                task.HotelId,
                task.PhysicalRoomId,
                room.RoomNumber,
                task.BookingId,
                task.AssignedToUserAccountId,
                task.TaskType,
                task.Status,
                room.Status,
                task.CreatedAtUtc))
            .FirstAsync(cancellationToken);
    }

}
