using HotelMarketplace.Application.Payments;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace HotelMarketplace.Infrastructure.Payment;

public static class DependencyInjection
{
    public static IServiceCollection AddPaymentInfrastructure(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        ArgumentNullException.ThrowIfNull(configuration);

        PayOsOptions options = new(
            configuration["PayOs:ClientId"] ?? string.Empty,
            configuration["PayOs:ApiKey"] ?? string.Empty,
            configuration["PayOs:ChecksumKey"] ?? string.Empty,
            configuration["PayOs:BaseUrl"] ?? "https://api-merchant.payos.vn",
            configuration["PayOs:ReturnUrl"] ?? "http://localhost:5080/api/payments/payos/return",
            configuration["PayOs:CancelUrl"] ?? "http://localhost:5080/api/payments/payos/cancel");

        services.AddSingleton(options);
        services.AddSingleton<IPayOsGateway, PayOsGateway>();

        return services;
    }
}
