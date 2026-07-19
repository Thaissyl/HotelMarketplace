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
    LockUnavailable = 10,
    InsufficientAvailability = 11,
    IncorrectCashAmount = 12,
    InvalidBookingStatusForNoShow = 13,
    NoShowWindowNotReached = 14
}

public enum PaymentCollectionPersistenceStatus
{
    Success = 1,
    BookingNotFound = 2,
    WrongPaymentMode = 3,
    InvalidCollectionAmount = 4,
    DuplicateCollectionReference = 5,
    LockUnavailable = 6
}

public sealed record PaymentCollectionPersistenceResult(
    PaymentCollectionPersistenceStatus Status,
    PaymentCollectionSummaryDto? Summary)
{
    public static PaymentCollectionPersistenceResult Success(PaymentCollectionSummaryDto summary) =>
        new(PaymentCollectionPersistenceStatus.Success, summary);

    public static PaymentCollectionPersistenceResult Failure(PaymentCollectionPersistenceStatus status) =>
        new(status, null);
}

public sealed record FrontDeskPersistenceResult(
    FrontDeskPersistenceStatus Status,
    FrontDeskBookingDto? Booking)
{
    public static FrontDeskPersistenceResult Success(FrontDeskBookingDto booking) => new(FrontDeskPersistenceStatus.Success, booking);

    public static FrontDeskPersistenceResult Failure(FrontDeskPersistenceStatus status) => new(status, null);
}
