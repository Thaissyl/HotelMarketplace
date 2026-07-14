namespace HotelMarketplace.Infrastructure.Scheduling;

internal sealed record BookingExpirationOptions(
    bool Enabled,
    int IntervalSeconds,
    int BatchSize)
{
    public TimeSpan Interval => TimeSpan.FromSeconds(Math.Clamp(IntervalSeconds, 10, 3600));

    public int NormalizedBatchSize => Math.Clamp(BatchSize, 1, 500);
}
