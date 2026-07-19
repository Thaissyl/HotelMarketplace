using HotelMarketplace.Application.Bookings.Dtos;

namespace HotelMarketplace.Application.Bookings;

public enum BookingCancellationPersistenceStatus
{
    Success = 1,
    BookingNotFound = 2,
    Forbidden = 3,
    InvalidBookingStatus = 4,
    LockUnavailable = 5
}

public sealed record BookingCancellationPersistenceResult(
    BookingCancellationPersistenceStatus Status,
    BookingCancellationResultDto? Cancellation)
{
    public static BookingCancellationPersistenceResult Success(BookingCancellationResultDto cancellation) =>
        new(BookingCancellationPersistenceStatus.Success, cancellation);

    public static BookingCancellationPersistenceResult Failure(BookingCancellationPersistenceStatus status) =>
        new(status, null);
}

public sealed record BookingCancellationQuotePersistenceResult(
    BookingCancellationPersistenceStatus Status,
    BookingCancellationQuoteDto? Quote)
{
    public static BookingCancellationQuotePersistenceResult Success(BookingCancellationQuoteDto quote) =>
        new(BookingCancellationPersistenceStatus.Success, quote);

    public static BookingCancellationQuotePersistenceResult Failure(BookingCancellationPersistenceStatus status) =>
        new(status, null);
}
