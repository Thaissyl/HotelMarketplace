namespace HotelMarketplace.Application.Bookings;

public interface IBookingRepository
{
    Task<CreateBookingRepositoryResult> CreatePendingBookingAsync(
        CreateBookingRepositoryRequest request,
        CancellationToken cancellationToken);
}
