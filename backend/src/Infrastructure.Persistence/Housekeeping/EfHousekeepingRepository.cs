using System.Data;
using System.Data.Common;
using System.Globalization;
using HotelMarketplace.Application.Housekeeping;
using HotelMarketplace.Application.Housekeeping.Dtos;
using HotelMarketplace.Application.Housekeeping.Requests;
using HotelMarketplace.Domain.Entities;
using HotelMarketplace.Domain.Enums;
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

            int lockResult = await AcquireLockAsync($"housekeeping:{hotelId:N}:{taskId:N}", cancellationToken);
            if (lockResult < 0)
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

                if (targetStatus == HousekeepingTaskStatus.InProgress)
                {
                    task.Start(actorUserAccountId);
                    room.StartHousekeeping();
                }
                else if (targetStatus == HousekeepingTaskStatus.Completed)
                {
                    task.Complete();
                    room.CompleteHousekeeping();
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
