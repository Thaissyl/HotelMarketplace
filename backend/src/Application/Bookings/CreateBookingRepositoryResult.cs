using HotelMarketplace.Application.Bookings.Dtos;

namespace HotelMarketplace.Application.Bookings;

public sealed record CreateBookingRepositoryResult(
    CreateBookingRepositoryStatus Status,
    BookingDto? Booking)
{
    public static CreateBookingRepositoryResult Success(BookingDto booking)
    {
        return new CreateBookingRepositoryResult(CreateBookingRepositoryStatus.Success, booking);
    }

    public static CreateBookingRepositoryResult Failure(CreateBookingRepositoryStatus status)
    {
        return new CreateBookingRepositoryResult(status, null);
    }
}

public enum CreateBookingRepositoryStatus
{
    Success = 1,
    HotelNotAvailable = 2,
    RoomTypeNotAvailable = 3,
    CapacityExceeded = 4,
    InsufficientAvailability = 5,
    ReservationLockUnavailable = 6
}
