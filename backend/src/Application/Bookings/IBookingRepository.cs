namespace HotelMarketplace.Application.Bookings;

public interface IBookingRepository
{
    Task<CreateBookingRepositoryResult> CreatePendingBookingAsync(
        CreateBookingRepositoryRequest request,
        CancellationToken cancellationToken);

    Task<IReadOnlyCollection<Dtos.BookingDto>> GetBookingsForCustomerAsync(
        Guid customerUserAccountId,
        CancellationToken cancellationToken);
}
