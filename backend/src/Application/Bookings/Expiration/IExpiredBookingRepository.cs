namespace HotelMarketplace.Application.Bookings.Expiration;

public interface IExpiredBookingRepository
{
    Task<IReadOnlyCollection<ExpiredBookingDto>> ExpirePendingPaymentBookingsAsync(
        DateTime utcNow,
        int batchSize,
        CancellationToken cancellationToken);
}
