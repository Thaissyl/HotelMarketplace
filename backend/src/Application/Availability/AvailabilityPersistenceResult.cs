using HotelMarketplace.Application.Availability.Dtos;

namespace HotelMarketplace.Application.Availability;

public enum AvailabilityPersistenceStatus
{
    Success = 1,
    HotelNotFound = 2,
    RoomTypeNotFound = 3,
    PhysicalRoomNotFound = 4,
    ActiveBookingConflict = 5,
    LockUnavailable = 6
}

public sealed record AvailabilityPersistenceResult(
    AvailabilityPersistenceStatus Status,
    AvailabilityCalendarDto? Calendar)
{
    public static AvailabilityPersistenceResult Success(AvailabilityCalendarDto calendar) =>
        new(AvailabilityPersistenceStatus.Success, calendar);

    public static AvailabilityPersistenceResult Failure(AvailabilityPersistenceStatus status) =>
        new(status, null);
}
