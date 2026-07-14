using HotelMarketplace.SharedKernel;
using HotelMarketplace.Application.Authentication;
using HotelMarketplace.Application.Security;
using Microsoft.Extensions.DependencyInjection;

namespace HotelMarketplace.Application;

public static class DependencyInjection
{
    public static IServiceCollection AddApplicationServices(this IServiceCollection services)
    {
        services.AddSharedKernel();
        services.AddScoped<IAuthService, AuthService>();
        services.AddScoped<IHotelAccessAuthorizer, HotelAccessAuthorizer>();

        return services;
    }
}
