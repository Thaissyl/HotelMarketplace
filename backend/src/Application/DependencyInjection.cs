using HotelMarketplace.SharedKernel;
using HotelMarketplace.Application.Authentication;
using HotelMarketplace.Application.HotelManagement;
using HotelMarketplace.Application.Security;
using FluentValidation;
using Microsoft.Extensions.DependencyInjection;

namespace HotelMarketplace.Application;

public static class DependencyInjection
{
    public static IServiceCollection AddApplicationServices(this IServiceCollection services)
    {
        services.AddSharedKernel();
        services.AddValidatorsFromAssembly(typeof(DependencyInjection).Assembly, includeInternalTypes: true);
        services.AddScoped<IAuthService, AuthService>();
        services.AddScoped<IHotelManagementService, HotelManagementService>();
        services.AddScoped<IHotelAccessAuthorizer, HotelAccessAuthorizer>();

        return services;
    }
}
