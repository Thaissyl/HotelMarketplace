using HotelMarketplace.SharedKernel.Time;
using HotelMarketplace.SharedKernel.Tenancy;
using Microsoft.Extensions.DependencyInjection;

namespace HotelMarketplace.SharedKernel;

public static class DependencyInjection
{
    public static IServiceCollection AddSharedKernel(this IServiceCollection services)
    {
        services.AddSingleton<IDateTimeProvider, SystemDateTimeProvider>();
        services.AddScoped<CurrentHotelContext>();
        services.AddScoped<ICurrentHotelContext>(provider => provider.GetRequiredService<CurrentHotelContext>());

        return services;
    }
}
