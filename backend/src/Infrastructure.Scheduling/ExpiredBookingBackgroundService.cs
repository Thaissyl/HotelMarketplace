using HotelMarketplace.Application.Bookings.Expiration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace HotelMarketplace.Infrastructure.Scheduling;

internal sealed class ExpiredBookingBackgroundService : BackgroundService
{
    private static readonly Action<ILogger, Exception?> LogDisabled =
        LoggerMessage.Define(LogLevel.Information, new EventId(1001, nameof(LogDisabled)), "Expired booking background service is disabled.");

    private static readonly Action<ILogger, double, int, Exception?> LogStarted =
        LoggerMessage.Define<double, int>(
            LogLevel.Information,
            new EventId(1002, nameof(LogStarted)),
            "Expired booking background service started. IntervalSeconds={IntervalSeconds}, BatchSize={BatchSize}.");

    private static readonly Action<ILogger, Exception?> LogNoExpiredBookings =
        LoggerMessage.Define(LogLevel.Debug, new EventId(1003, nameof(LogNoExpiredBookings)), "Expired booking scan completed. No unpaid bookings expired.");

    private static readonly Action<ILogger, int, string, Exception?> LogExpiredBookings =
        LoggerMessage.Define<int, string>(
            LogLevel.Information,
            new EventId(1004, nameof(LogExpiredBookings)),
            "Expired booking scan completed. ExpiredCount={ExpiredCount}, BookingCodes={BookingCodes}.");

    private static readonly Action<ILogger, int, Exception?> LogScanRecovered =
        LoggerMessage.Define<int>(
            LogLevel.Information,
            new EventId(1005, nameof(LogScanRecovered)),
            "Expired booking background service recovered after {ConsecutiveFailureCount} consecutive failed scan(s).");

    private static readonly Action<ILogger, int, Exception> LogScanFailed =
        LoggerMessage.Define<int>(
            LogLevel.Error,
            new EventId(1006, nameof(LogScanFailed)),
            "Expired booking background service failed during scan. ConsecutiveFailureCount={ConsecutiveFailureCount}.");

    private readonly IServiceScopeFactory _serviceScopeFactory;
    private readonly BookingExpirationOptions _options;
    private readonly ILogger<ExpiredBookingBackgroundService> _logger;
    private int _consecutiveFailureCount;

    public ExpiredBookingBackgroundService(
        IServiceScopeFactory serviceScopeFactory,
        BookingExpirationOptions options,
        ILogger<ExpiredBookingBackgroundService> logger)
    {
        _serviceScopeFactory = serviceScopeFactory;
        _options = options;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if (!_options.Enabled)
        {
            LogDisabled(_logger, null);
            return;
        }

        LogStarted(_logger, _options.Interval.TotalSeconds, _options.NormalizedBatchSize, null);

        using PeriodicTimer timer = new(_options.Interval);

        await ExpireBookingsAsync(stoppingToken);

        while (await timer.WaitForNextTickAsync(stoppingToken))
        {
            await ExpireBookingsAsync(stoppingToken);
        }
    }

    private async Task ExpireBookingsAsync(CancellationToken stoppingToken)
    {
        try
        {
            using IServiceScope scope = _serviceScopeFactory.CreateScope();
            IExpiredBookingService expiredBookingService = scope.ServiceProvider.GetRequiredService<IExpiredBookingService>();

            ExpireUnpaidBookingsResult result = await expiredBookingService.ExpireUnpaidBookingsAsync(
                _options.NormalizedBatchSize,
                stoppingToken);

            LogRecoveryIfNeeded();

            if (result.ExpiredCount == 0)
            {
                LogNoExpiredBookings(_logger, null);
                return;
            }

            LogExpiredBookings(
                _logger,
                result.ExpiredCount,
                string.Join(",", result.ExpiredBookings.Select(booking => booking.BookingCode)),
                null);
        }
        catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
        {
        }
        catch (Exception exception)
        {
            int failureCount = Interlocked.Increment(ref _consecutiveFailureCount);
            LogScanFailed(_logger, failureCount, exception);
        }
    }

    private void LogRecoveryIfNeeded()
    {
        int failureCount = Interlocked.Exchange(ref _consecutiveFailureCount, 0);

        if (failureCount > 0)
        {
            LogScanRecovered(_logger, failureCount, null);
        }
    }
}
