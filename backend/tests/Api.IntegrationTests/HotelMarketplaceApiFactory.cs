using HotelMarketplace.Infrastructure.Persistence;
using HotelMarketplace.Application.Security;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using System.Text;
using Testcontainers.MsSql;
using Xunit;

namespace HotelMarketplace.Api.IntegrationTests;

public sealed class HotelMarketplaceApiFactory : WebApplicationFactory<Program>, IAsyncLifetime
{
    private const string TestIssuer = "HotelMarketplace.IntegrationTests";
    private const string TestAudience = "HotelMarketplace.IntegrationTests";
    private const string TestSigningKey = "integration-test-signing-key-32-bytes-minimum";

    private readonly MsSqlContainer _sqlServer = new MsSqlBuilder()
        .WithPassword("Your_password123")
        .Build();

    public string ConnectionString => _sqlServer.GetConnectionString();

    public async Task InitializeAsync()
    {
        await _sqlServer.StartAsync();

        using IServiceScope scope = Services.CreateScope();
        HotelMarketplaceDbContext dbContext = scope.ServiceProvider.GetRequiredService<HotelMarketplaceDbContext>();
        await dbContext.Database.MigrateAsync();
    }

    public new async Task DisposeAsync()
    {
        await _sqlServer.DisposeAsync();
    }

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Development");

        builder.ConfigureLogging(logging =>
        {
            logging.ClearProviders();
            logging.AddConsole();
            logging.SetMinimumLevel(LogLevel.Debug);
        });

        builder.ConfigureAppConfiguration(configurationBuilder =>
        {
            Dictionary<string, string?> configuration = new()
            {
                ["ConnectionStrings:DefaultConnection"] = ConnectionString,
                ["Jwt:Issuer"] = TestIssuer,
                ["Jwt:Audience"] = TestAudience,
                ["Jwt:SigningKey"] = TestSigningKey,
                ["Scheduling:BookingExpiration:Enabled"] = "false",
                ["PayOs:ClientId"] = "test-client-id",
                ["PayOs:ApiKey"] = "test-api-key",
                ["PayOs:ChecksumKey"] = "test-checksum-key",
                ["PayOs:BaseUrl"] = "https://example.invalid",
                ["PayOs:ReturnUrl"] = "https://example.invalid/return",
                ["PayOs:CancelUrl"] = "https://example.invalid/cancel"
            };

            configurationBuilder.AddInMemoryCollection(configuration);
        });

        builder.ConfigureServices(services =>
        {
            services.AddSingleton<IOptions<JwtOptions>>(Options.Create(new JwtOptions
            {
                Issuer = TestIssuer,
                Audience = TestAudience,
                SigningKey = TestSigningKey,
                ExpirationMinutes = 60
            }));

            services.PostConfigure<JwtBearerOptions>(JwtBearerDefaults.AuthenticationScheme, options =>
            {
                options.TokenValidationParameters = new TokenValidationParameters
                {
                    ValidateIssuer = true,
                    ValidIssuer = TestIssuer,
                    ValidateAudience = true,
                    ValidAudience = TestAudience,
                    ValidateIssuerSigningKey = true,
                    IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(TestSigningKey)),
                    ValidateLifetime = true,
                    ClockSkew = TimeSpan.FromMinutes(1),
                    NameClaimType = SecurityClaimTypes.UserId,
                    RoleClaimType = SecurityClaimTypes.Role
                };
            });
        });
    }
}
