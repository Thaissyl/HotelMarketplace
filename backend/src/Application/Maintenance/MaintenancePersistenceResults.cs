using HotelMarketplace.Application.Maintenance.Dtos;

namespace HotelMarketplace.Application.Maintenance;

public enum MaintenancePersistenceStatus
{
    Success = 1,
    RequestNotFound = 2,
    RoomNotFound = 3,
    InvalidTransition = 4,
    InvalidRoomStatus = 5,
    LockUnavailable = 6
}

public sealed record MaintenanceRequestPersistenceResult(
    MaintenancePersistenceStatus Status,
    MaintenanceRequestDto? Request)
{
    public static MaintenanceRequestPersistenceResult Success(MaintenanceRequestDto request) => new(MaintenancePersistenceStatus.Success, request);

    public static MaintenanceRequestPersistenceResult Failure(MaintenancePersistenceStatus status) => new(status, null);
}
