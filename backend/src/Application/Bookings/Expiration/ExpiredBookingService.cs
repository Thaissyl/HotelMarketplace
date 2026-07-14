using HotelMarketplace.SharedKernel.Time;

namespace HotelMarketplace.Application.Bookings.Expiration;

internal sealed class ExpiredBookingService : IExpiredBookingService
{
    private readonly IExpiredBookingRepository _expiredBookingRepository;
    private readonly IDateTimeProvider _dateTimeProvider;

    public ExpiredBookingService(
        IExpiredBookingRepository expiredBookingRepository,
        IDateTimeProvider dateTimeProvider)
    {
        _expiredBookingRepository = expiredBookingRepository;
        _dateTimeProvider = dateTimeProvider;
    }

    public async Task<ExpireUnpaidBookingsResult> ExpireUnpaidBookingsAsync(
        int batchSize,
        CancellationToken cancellationToken)
    {
        int normalizedBatchSize = Math.Clamp(batchSize, 1, 500);
        IReadOnlyCollection<ExpiredBookingDto> expiredBookings = await _expiredBookingRepository.ExpirePendingPaymentBookingsAsync(
            _dateTimeProvider.UtcNow,
            normalizedBatchSize,
            cancellationToken);

        return new ExpireUnpaidBookingsResult(expiredBookings.Count, expiredBookings);
    }
}
