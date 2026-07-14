using System.Data;
using System.Data.Common;
using System.Globalization;
using HotelMarketplace.Application.Maintenance;
using HotelMarketplace.Application.Maintenance.Dtos;
using HotelMarketplace.Application.Maintenance.Requests;
using HotelMarketplace.Domain.Entities;
using HotelMarketplace.Domain.Enums;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;

namespace HotelMarketplace.Infrastructure.Persistence.Maintenance;

internal sealed class EfMaintenanceRepository : IMaintenanceRepository
{
    private readonly HotelMarketplaceDbContext _dbContext;

    public EfMaintenanceRepository(HotelMarketplaceDbContext dbContext)
    {
        _dbContext = dbContext;
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
                maintenanceRequest.CreatedAtUtc))
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

            int lockResult = await AcquireLockAsync($"maintenance:room:{hotelId:N}:{request.PhysicalRoomId:N}", cancellationToken);
            if (lockResult < 0)
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
        MaintenanceStatus targetStatus,
        CancellationToken cancellationToken)
    {
        IExecutionStrategy executionStrategy = _dbContext.Database.CreateExecutionStrategy();

        return await executionStrategy.ExecuteAsync(async () =>
        {
            await using IDbContextTransaction transaction = await _dbContext.Database.BeginTransactionAsync(
                IsolationLevel.Serializable,
                cancellationToken);

            int lockResult = await AcquireLockAsync($"maintenance:request:{hotelId:N}:{requestId:N}", cancellationToken);
            if (lockResult < 0)
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
                if (targetStatus == MaintenanceStatus.InProgress)
                {
                    maintenanceRequest.Start(actorUserAccountId);
                }
                else if (targetStatus == MaintenanceStatus.Resolved)
                {
                    RoomOperationalStatus oldStatus = room.Status;
                    maintenanceRequest.Resolve();
                    room.ReleaseFromMaintenance();

                    await _dbContext.RoomStatusHistories.AddAsync(
                        new RoomStatusHistory(Guid.NewGuid(), hotelId, room.Id, oldStatus, room.Status, actorUserAccountId),
                        cancellationToken);
                }
                else
                {
                    await transaction.RollbackAsync(cancellationToken);
                    return MaintenanceRequestPersistenceResult.Failure(MaintenancePersistenceStatus.InvalidTransition);
                }
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
                maintenanceRequest.CreatedAtUtc))
            .FirstAsync(cancellationToken);
    }

    private async Task<int> AcquireLockAsync(
        string resource,
        CancellationToken cancellationToken)
    {
        DbConnection connection = _dbContext.Database.GetDbConnection();
        await using DbCommand command = connection.CreateCommand();
        command.Transaction = _dbContext.Database.CurrentTransaction?.GetDbTransaction();
        command.CommandText = """
            DECLARE @lockResult int;
            EXEC @lockResult = sys.sp_getapplock
                @Resource = @resource,
                @LockMode = 'Exclusive',
                @LockOwner = 'Transaction',
                @LockTimeout = @lockTimeout;
            SELECT @lockResult;
            """;

        DbParameter resourceParameter = command.CreateParameter();
        resourceParameter.ParameterName = "@resource";
        resourceParameter.DbType = DbType.String;
        resourceParameter.Value = resource;
        command.Parameters.Add(resourceParameter);

        DbParameter timeoutParameter = command.CreateParameter();
        timeoutParameter.ParameterName = "@lockTimeout";
        timeoutParameter.DbType = DbType.Int32;
        timeoutParameter.Value = 10_000;
        command.Parameters.Add(timeoutParameter);

        object? result = await command.ExecuteScalarAsync(cancellationToken);
        return Convert.ToInt32(result, CultureInfo.InvariantCulture);
    }
}
