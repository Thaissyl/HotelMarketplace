using HotelMarketplace.Application.FrontDesk.Dtos;

namespace HotelMarketplace.Application.FrontDesk;

public enum FrontDeskPersistenceStatus
{
    Success = 1,
    BookingNotFound = 2,
    RoomTypeNotAvailable = 3,
    InvalidBookingStatusForCheckIn = 4,
    InvalidBookingStatusForCheckOut = 5,
    InvalidRoomAssignment = 6,
    RoomAssignmentOverlap = 7,
    PaymentCollectionRequired = 8,
    CapacityExceeded = 9,
    LockUnavailable = 10
}

public sealed record FrontDeskPersistenceResult(
    FrontDeskPersistenceStatus Status,
    FrontDeskBookingDto? Booking)
{
    public static FrontDeskPersistenceResult Success(FrontDeskBookingDto booking) => new(FrontDeskPersistenceStatus.Success, booking);

    public static FrontDeskPersistenceResult Failure(FrontDeskPersistenceStatus status) => new(status, null);
}
