namespace HotelMarketplace.Application.Bookings.Expiration;

public interface IExpiredBookingService
{
    Task<ExpireUnpaidBookingsResult> ExpireUnpaidBookingsAsync(
        int batchSize,
        CancellationToken cancellationToken);
}
