namespace HotelMarketplace.Application.Bookings;

public interface IBookingRepository
{
    Task<CreateBookingRepositoryResult> CreatePendingBookingAsync(
        CreateBookingRepositoryRequest request,
        CancellationToken cancellationToken);

    Task<IReadOnlyCollection<Dtos.BookingDto>> GetBookingsForCustomerAsync(
        Guid customerUserAccountId,
        CancellationToken cancellationToken);

    Task<BookingCancellationQuotePersistenceResult> GetCancellationQuoteAsync(
        Guid bookingId,
        Guid customerUserAccountId,
        CancellationToken cancellationToken);

    Task<BookingCancellationPersistenceResult> CancelBookingAsync(
        Guid bookingId,
        Guid customerUserAccountId,
        string reason,
        CancellationToken cancellationToken);
}
