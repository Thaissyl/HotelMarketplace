using HotelMarketplace.Application.Authentication;
using HotelMarketplace.Application.Availability;
using HotelMarketplace.Application.Bookings;
using HotelMarketplace.Application.Bookings.Expiration;
using HotelMarketplace.Application.CustomerAccount;
using HotelMarketplace.Application.CustomerEngagement;
using HotelMarketplace.Application.FrontDesk;
using HotelMarketplace.Application.Housekeeping;
using HotelMarketplace.Application.HotelManagement;
using HotelMarketplace.Application.Inventory;
using HotelMarketplace.Application.Maintenance;
using HotelMarketplace.Application.Marketplace;
using HotelMarketplace.Application.Payments;
using HotelMarketplace.Application.PlatformAdmin;
using HotelMarketplace.Application.Security;
using HotelMarketplace.Infrastructure.Persistence.Authentication;
using HotelMarketplace.Infrastructure.Persistence.Availability;
using HotelMarketplace.Infrastructure.Persistence.Bookings;
using HotelMarketplace.Infrastructure.Persistence.CustomerAccount;
using HotelMarketplace.Infrastructure.Persistence.CustomerEngagement;
using HotelMarketplace.Infrastructure.Persistence.FrontDesk;
using HotelMarketplace.Infrastructure.Persistence.Housekeeping;
using HotelMarketplace.Infrastructure.Persistence.HotelManagement;
using HotelMarketplace.Infrastructure.Persistence.Inventory;
using HotelMarketplace.Infrastructure.Persistence.Maintenance;
using HotelMarketplace.Infrastructure.Persistence.Marketplace;
using HotelMarketplace.Infrastructure.Persistence.Payments;
using HotelMarketplace.Infrastructure.Persistence.PlatformAdmin;
using HotelMarketplace.Infrastructure.Persistence.Security;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.EntityFrameworkCore;

namespace HotelMarketplace.Infrastructure.Persistence;

public static class DependencyInjection
{
    public static IServiceCollection AddPersistenceInfrastructure(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        ArgumentNullException.ThrowIfNull(configuration);

        string connectionString = configuration.GetConnectionString("DefaultConnection")
            ?? throw new InvalidOperationException("Connection string 'DefaultConnection' is not configured.");

        services.AddDbContext<HotelMarketplaceDbContext>(options =>
        {
            options.UseSqlServer(connectionString, sqlServerOptions =>
            {
                sqlServerOptions.MigrationsAssembly(typeof(HotelMarketplaceDbContext).Assembly.FullName);
                sqlServerOptions.EnableRetryOnFailure(
                    maxRetryCount: 5,
                    maxRetryDelay: TimeSpan.FromSeconds(10),
                    errorNumbersToAdd: null);
            });
        });

        services.AddScoped<IAuthUserRepository, EfAuthUserRepository>();
        services.AddScoped<IAvailabilityRepository, EfAvailabilityRepository>();
        services.AddScoped<IHotelAccessRepository, EfHotelAccessRepository>();
        services.AddScoped<IInventoryCommitmentCoordinator, EfInventoryCommitmentCoordinator>();
        services.AddScoped<IBookingRepository, EfBookingRepository>();
        services.AddScoped<ICustomerAccountRepository, EfCustomerAccountRepository>();
        services.AddScoped<ICustomerEngagementRepository, EfCustomerEngagementRepository>();
        services.AddScoped<IExpiredBookingRepository, EfExpiredBookingRepository>();
        services.AddScoped<IFrontDeskRepository, EfFrontDeskRepository>();
        string? configuredNoShowHours = configuration["Operations:NoShowEligibleAfterHours"];
        int noShowEligibleAfterHours = string.IsNullOrWhiteSpace(configuredNoShowHours)
            ? NoShowPolicyOptions.DefaultEligibleAfterHours
            : int.TryParse(configuredNoShowHours, out int parsedNoShowHours)
                ? parsedNoShowHours
                : throw new InvalidOperationException("Operations:NoShowEligibleAfterHours must be an integer.");
        if (noShowEligibleAfterHours is < 0 or > 168)
        {
            throw new InvalidOperationException("Operations:NoShowEligibleAfterHours must be between 0 and 168.");
        }

        services.AddSingleton(new NoShowPolicyOptions(noShowEligibleAfterHours));
        services.AddScoped<IHousekeepingRepository, EfHousekeepingRepository>();
        services.AddScoped<IHotelManagementRepository, EfHotelManagementRepository>();
        services.AddScoped<IMaintenanceRepository, EfMaintenanceRepository>();
        services.AddScoped<IMarketplaceBrowsingRepository, EfMarketplaceBrowsingRepository>();
        services.AddScoped<IPaymentRepository, EfPaymentRepository>();
        services.AddScoped<IPlatformAdminRepository, EfPlatformAdminRepository>();
        services.AddSingleton<IPasswordHasher, Pbkdf2PasswordHasher>();
        services.AddSingleton<IJwtTokenGenerator, JwtTokenGenerator>();

        return services;
    }
}
