using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace HotelMarketplace.Infrastructure.Scheduling;

public static class DependencyInjection
{
    public static IServiceCollection AddSchedulingInfrastructure(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        ArgumentNullException.ThrowIfNull(configuration);

        BookingExpirationOptions options = new(
            configuration.GetValue("Scheduling:BookingExpiration:Enabled", true),
            configuration.GetValue("Scheduling:BookingExpiration:IntervalSeconds", 60),
            configuration.GetValue("Scheduling:BookingExpiration:BatchSize", 100));

        services.AddSingleton(options);
        services.AddHostedService<ExpiredBookingBackgroundService>();

        return services;
    }
}
