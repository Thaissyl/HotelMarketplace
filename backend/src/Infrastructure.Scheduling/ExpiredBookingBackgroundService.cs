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

    private static readonly Action<ILogger, Exception?> LogScanFailed =
        LoggerMessage.Define(LogLevel.Error, new EventId(1005, nameof(LogScanFailed)), "Expired booking background service failed during scan.");

    private readonly IServiceScopeFactory _serviceScopeFactory;
    private readonly BookingExpirationOptions _options;
    private readonly ILogger<ExpiredBookingBackgroundService> _logger;

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
            LogScanFailed(_logger, exception);
        }
    }
}
