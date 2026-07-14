using HotelMarketplace.SharedKernel;
using Microsoft.Extensions.DependencyInjection;

namespace HotelMarketplace.Application;

public static class DependencyInjection
{
    public static IServiceCollection AddApplicationServices(this IServiceCollection services)
    {
        services.AddSharedKernel();

        return services;
    }
}
