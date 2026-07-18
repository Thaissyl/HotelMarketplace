using HotelMarketplace.SharedKernel;
using HotelMarketplace.Application.Authentication;
using HotelMarketplace.Application.Bookings;
using HotelMarketplace.Application.Bookings.Expiration;
using HotelMarketplace.Application.CustomerAccount;
using HotelMarketplace.Application.FrontDesk;
using HotelMarketplace.Application.Housekeeping;
using HotelMarketplace.Application.HotelManagement;
using HotelMarketplace.Application.Maintenance;
using HotelMarketplace.Application.Marketplace;
using HotelMarketplace.Application.Payments;
using HotelMarketplace.Application.PlatformAdmin;
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
        services.AddScoped<IBookingService, BookingService>();
        services.AddScoped<ICustomerAccountService, CustomerAccountService>();
        services.AddScoped<IExpiredBookingService, ExpiredBookingService>();
        services.AddScoped<IFrontDeskService, FrontDeskService>();
        services.AddScoped<IHousekeepingService, HousekeepingService>();
        services.AddScoped<IHotelManagementService, HotelManagementService>();
        services.AddScoped<IMaintenanceService, MaintenanceService>();
        services.AddScoped<IMarketplaceBrowsingService, MarketplaceBrowsingService>();
        services.AddScoped<IPaymentService, PaymentService>();
        services.AddScoped<IPlatformAdminService, PlatformAdminService>();
        services.AddScoped<IHotelAccessAuthorizer, HotelAccessAuthorizer>();

        return services;
    }
}
