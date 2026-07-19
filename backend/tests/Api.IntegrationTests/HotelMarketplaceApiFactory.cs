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
    private readonly Dictionary<string, string?> _originalEnvironmentValues = new(StringComparer.Ordinal);

    public string ConnectionString => _sqlServer.GetConnectionString();

    public async Task InitializeAsync()
    {
        await _sqlServer.StartAsync();
        ConfigureTestEnvironment();

        using IServiceScope scope = Services.CreateScope();
        HotelMarketplaceDbContext dbContext = scope.ServiceProvider.GetRequiredService<HotelMarketplaceDbContext>();
        await dbContext.Database.MigrateAsync();
    }

    public new async Task DisposeAsync()
    {
        RestoreEnvironment();
        await _sqlServer.DisposeAsync();
    }

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");

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
                ["Payment:Mode"] = "Demo"
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

    private void ConfigureTestEnvironment()
    {
        Dictionary<string, string> testValues = new(StringComparer.Ordinal)
        {
            ["ASPNETCORE_ENVIRONMENT"] = "Testing",
            ["ConnectionStrings__DefaultConnection"] = ConnectionString,
            ["Jwt__Issuer"] = TestIssuer,
            ["Jwt__Audience"] = TestAudience,
            ["Jwt__SigningKey"] = TestSigningKey,
            ["Scheduling__BookingExpiration__Enabled"] = "false",
            ["Payment__Mode"] = "Demo"
        };

        foreach ((string key, string value) in testValues)
        {
            _originalEnvironmentValues[key] = Environment.GetEnvironmentVariable(key, EnvironmentVariableTarget.Process);
            Environment.SetEnvironmentVariable(key, value, EnvironmentVariableTarget.Process);
        }
    }

    private void RestoreEnvironment()
    {
        foreach ((string key, string? value) in _originalEnvironmentValues)
        {
            Environment.SetEnvironmentVariable(key, value, EnvironmentVariableTarget.Process);
        }

        _originalEnvironmentValues.Clear();
    }
}
