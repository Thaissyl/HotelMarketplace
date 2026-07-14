using HotelMarketplace.Application.Housekeeping.Dtos;

namespace HotelMarketplace.Application.Housekeeping;

public enum HousekeepingPersistenceStatus
{
    Success = 1,
    TaskNotFound = 2,
    RoomNotFound = 3,
    InvalidTransition = 4,
    LockUnavailable = 5
}

public sealed record HousekeepingTaskUpdateResult(
    HousekeepingPersistenceStatus Status,
    HousekeepingTaskDto? Task)
{
    public static HousekeepingTaskUpdateResult Success(HousekeepingTaskDto task) => new(HousekeepingPersistenceStatus.Success, task);

    public static HousekeepingTaskUpdateResult Failure(HousekeepingPersistenceStatus status) => new(status, null);
}
