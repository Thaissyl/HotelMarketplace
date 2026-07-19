using HotelMarketplace.Domain.Entities;

namespace HotelMarketplace.Application.HotelManagement;

public sealed record PhysicalRoomPersistenceResult(
    PhysicalRoomPersistenceStatus Status,
    PhysicalRoom? PhysicalRoom)
{
    public static PhysicalRoomPersistenceResult Success(PhysicalRoom physicalRoom)
    {
        return new PhysicalRoomPersistenceResult(PhysicalRoomPersistenceStatus.Success, physicalRoom);
    }

    public static PhysicalRoomPersistenceResult Failure(PhysicalRoomPersistenceStatus status)
    {
        return new PhysicalRoomPersistenceResult(status, null);
    }
}

public enum PhysicalRoomPersistenceStatus
{
    Success = 1,
    RoomTypeNotFound = 2,
    PhysicalRoomNotFound = 3,
    DuplicateRoomNumber = 4,
    RoomIsOccupied = 5,
    InvalidRoomStatus = 6,
    LockUnavailable = 7,
    OperationalLifecycleActive = 8
}
