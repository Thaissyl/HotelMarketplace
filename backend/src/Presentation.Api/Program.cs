using System.Globalization;
using System.Text;
using HotelMarketplace.Application;
using HotelMarketplace.Infrastructure.Notification;
using HotelMarketplace.Infrastructure.Payment;
using HotelMarketplace.Infrastructure.Persistence;
using HotelMarketplace.Infrastructure.Scheduling;
using HotelMarketplace.Presentation.Api.Middleware;
using HotelMarketplace.Presentation.Api.Options;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.IdentityModel.Tokens;
using Serilog;

Log.Logger = new LoggerConfiguration()
    .Enrich.FromLogContext()
    .WriteTo.Console(formatProvider: CultureInfo.InvariantCulture)
    .CreateLogger();

try
{
    WebApplicationBuilder builder = WebApplication.CreateBuilder(args);

    LoadLocalEnvironmentFile(builder);

    builder.Host.UseSerilog((context, services, loggerConfiguration) =>
    {
        loggerConfiguration
            .ReadFrom.Services(services)
            .Enrich.FromLogContext()
            .WriteTo.Console(formatProvider: CultureInfo.InvariantCulture);
    });

    builder.Services.AddControllers();
    builder.Services.AddEndpointsApiExplorer();
    builder.Services.AddSwaggerGen();
    builder.Services.AddProblemDetails();
    builder.Services.AddExceptionHandler<GlobalExceptionHandler>();
    builder.Services.AddHealthChecks();

    builder.Services.Configure<JwtOptions>(
        builder.Configuration.GetSection(JwtOptions.SectionName));

    builder.Services.Configure<CorsOptions>(
        builder.Configuration.GetSection(CorsOptions.SectionName));

    AddCors(builder);
    AddAuthentication(builder);

    builder.Services.AddAuthorization();
    builder.Services.AddApplicationServices();
    builder.Services.AddPersistenceInfrastructure(builder.Configuration);
    builder.Services.AddPaymentInfrastructure(builder.Configuration);
    builder.Services.AddNotificationInfrastructure(builder.Configuration);
    builder.Services.AddSchedulingInfrastructure(builder.Configuration);

    WebApplication app = builder.Build();

    app.UseExceptionHandler();

    if (app.Environment.IsDevelopment())
    {
        app.UseSwagger();
        app.UseSwaggerUI();
    }

    app.UseHttpsRedirection();
    app.UseCors("MobileClient");
    app.UseAuthentication();
    app.UseAuthorization();

    app.MapControllers();

    app.MapHealthChecks("/health", new HealthCheckOptions
    {
        ResponseWriter = async (context, report) =>
        {
            context.Response.ContentType = "application/json";

            var response = new
            {
                status = report.Status.ToString(),
                checks = report.Entries.Select(entry => new
                {
                    name = entry.Key,
                    status = entry.Value.Status.ToString(),
                    duration = entry.Value.Duration.TotalMilliseconds
                })
            };

            await context.Response.WriteAsJsonAsync(response);
        }
    });

    app.MapGet("/", () => Results.Ok(new
    {
        name = "Hotel Marketplace Management System API",
        status = "Running"
    }));

    app.Run();
}
catch (Exception exception)
    when (exception.GetType().Name == "HostAbortedException")
{
}
catch (Exception exception)
{
    Log.Fatal(exception, "API host terminated unexpectedly.");
}
finally
{
    Log.CloseAndFlush();
}

static void AddCors(WebApplicationBuilder builder)
{
    CorsOptions corsOptions = builder.Configuration
        .GetSection(CorsOptions.SectionName)
        .Get<CorsOptions>() ?? new CorsOptions();

    builder.Services.AddCors(options =>
    {
        options.AddPolicy("MobileClient", policy =>
        {
            if (corsOptions.AllowedOrigins.Length > 0)
            {
                policy.WithOrigins(corsOptions.AllowedOrigins)
                    .AllowAnyHeader()
                    .AllowAnyMethod();

                return;
            }

            policy.AllowAnyOrigin()
                .AllowAnyHeader()
                .AllowAnyMethod();
        });
    });
}

static void AddAuthentication(WebApplicationBuilder builder)
{
    JwtOptions jwtOptions = builder.Configuration
        .GetSection(JwtOptions.SectionName)
        .Get<JwtOptions>() ?? new JwtOptions();

    if (string.IsNullOrWhiteSpace(jwtOptions.Issuer))
    {
        throw new InvalidOperationException("JWT issuer is not configured.");
    }

    if (string.IsNullOrWhiteSpace(jwtOptions.Audience))
    {
        throw new InvalidOperationException("JWT audience is not configured.");
    }

    if (string.IsNullOrWhiteSpace(jwtOptions.SigningKey))
    {
        throw new InvalidOperationException("JWT signing key is not configured.");
    }

    byte[] signingKeyBytes = Encoding.UTF8.GetBytes(jwtOptions.SigningKey);

    if (signingKeyBytes.Length < 32)
    {
        throw new InvalidOperationException("JWT signing key must be at least 32 bytes long.");
    }

    builder.Services
        .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
        .AddJwtBearer(options =>
        {
            options.RequireHttpsMetadata = !builder.Environment.IsDevelopment();
            options.SaveToken = false;
            options.TokenValidationParameters = new TokenValidationParameters
            {
                ValidateIssuer = true,
                ValidIssuer = jwtOptions.Issuer,
                ValidateAudience = true,
                ValidAudience = jwtOptions.Audience,
                ValidateIssuerSigningKey = true,
                IssuerSigningKey = new SymmetricSecurityKey(signingKeyBytes),
                ValidateLifetime = true,
                ClockSkew = TimeSpan.FromMinutes(1)
            };
        });
}

static void LoadLocalEnvironmentFile(WebApplicationBuilder builder)
{
    string environmentFilePath = Path.Combine(builder.Environment.ContentRootPath, ".env");

    if (!File.Exists(environmentFilePath))
    {
        environmentFilePath = Path.GetFullPath(Path.Combine(builder.Environment.ContentRootPath, "..", "..", "..", ".env"));
    }

    if (!File.Exists(environmentFilePath))
    {
        return;
    }

    Dictionary<string, string?> configurationValues = new(StringComparer.OrdinalIgnoreCase);

    foreach (string rawLine in File.ReadLines(environmentFilePath))
    {
        string line = rawLine.Trim();

        if (string.IsNullOrWhiteSpace(line) || line[0] == '#')
        {
            continue;
        }

        int separatorIndex = line.IndexOf('=');

        if (separatorIndex <= 0)
        {
            continue;
        }

        string key = line[..separatorIndex].Trim();
        string value = line[(separatorIndex + 1)..].Trim().Trim('"');

        AddMappedConfigurationValue(configurationValues, key, value);
    }

    if (configurationValues.TryGetValue("SQLSERVER_HOST", out string? sqlServerHost) &&
        configurationValues.TryGetValue("SQLSERVER_PORT", out string? sqlServerPort) &&
        configurationValues.TryGetValue("SQLSERVER_DATABASE", out string? sqlServerDatabase) &&
        configurationValues.TryGetValue("SQLSERVER_USER", out string? sqlServerUser) &&
        configurationValues.TryGetValue("SA_PASSWORD", out string? sqlServerPassword))
    {
        configurationValues["ConnectionStrings:DefaultConnection"] =
            $"Server={sqlServerHost},{sqlServerPort};Database={sqlServerDatabase};User Id={sqlServerUser};Password={sqlServerPassword};TrustServerCertificate=True;MultipleActiveResultSets=True";
    }

    builder.Configuration.AddInMemoryCollection(configurationValues);
}

static void AddMappedConfigurationValue(
    IDictionary<string, string?> configurationValues,
    string key,
    string value)
{
    string? mappedKey = key switch
    {
        "JWT_ISSUER" => "Jwt:Issuer",
        "JWT_AUDIENCE" => "Jwt:Audience",
        "JWT_SIGNING_KEY" => "Jwt:SigningKey",
        "PAYOS_CLIENT_ID" => "PayOs:ClientId",
        "PAYOS_API_KEY" => "PayOs:ApiKey",
        "PAYOS_CHECKSUM_KEY" => "PayOs:ChecksumKey",
        "ASPNETCORE_ENVIRONMENT" => "ASPNETCORE_ENVIRONMENT",
        "SQLSERVER_HOST" => "SQLSERVER_HOST",
        "SQLSERVER_PORT" => "SQLSERVER_PORT",
        "SQLSERVER_DATABASE" => "SQLSERVER_DATABASE",
        "SQLSERVER_USER" => "SQLSERVER_USER",
        "SA_PASSWORD" => "SA_PASSWORD",
        _ => null
    };

    if (mappedKey is not null)
    {
        configurationValues[mappedKey] = value;
    }
}
