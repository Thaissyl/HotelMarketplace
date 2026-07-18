using System.Globalization;
using System.IdentityModel.Tokens.Jwt;
using System.Text;
using System.Text.Json.Serialization;
using HotelMarketplace.Application;
using HotelMarketplace.Application.Security;
using HotelMarketplace.Infrastructure.Notification;
using HotelMarketplace.Infrastructure.Payment;
using HotelMarketplace.Infrastructure.Persistence;
using HotelMarketplace.Infrastructure.Scheduling;
using HotelMarketplace.Presentation.Api.Authorization;
using HotelMarketplace.Presentation.Api.Middleware;
using HotelMarketplace.Presentation.Api.Options;
using HotelMarketplace.Presentation.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using Serilog;

JwtSecurityTokenHandler.DefaultMapInboundClaims = false;

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

    builder.Services.AddControllers()
        .AddJsonOptions(options =>
        {
            options.JsonSerializerOptions.Converters.Add(new JsonStringEnumConverter());
        });
    builder.Services.AddEndpointsApiExplorer();
    AddSwagger(builder);
    builder.Services.AddProblemDetails();
    builder.Services.AddExceptionHandler<GlobalExceptionHandler>();
    builder.Services.AddHealthChecks();
    builder.Services.AddHttpContextAccessor();

    builder.Services.Configure<JwtOptions>(
        builder.Configuration.GetSection(JwtOptions.SectionName));

    builder.Services.Configure<CorsOptions>(
        builder.Configuration.GetSection(CorsOptions.SectionName));

    AddCors(builder);
    AddAuthentication(builder);
    AddAuthorization(builder);

    builder.Services.AddApplicationServices();
    builder.Services.AddPersistenceInfrastructure(builder.Configuration);
    builder.Services.AddPaymentInfrastructure(builder.Configuration);
    builder.Services.AddNotificationInfrastructure(builder.Configuration);
    builder.Services.AddSchedulingInfrastructure(builder.Configuration);
    builder.Services.AddScoped<ICurrentUserService, HttpContextCurrentUserService>();
    builder.Services.AddScoped<IAuthorizationHandler, HotelScopedAuthorizationHandler>();

    WebApplication app = builder.Build();

    app.UseExceptionHandler();

    if (app.Environment.IsDevelopment())
    {
        app.UseSwagger();
        app.UseSwaggerUI();
    }

    app.UseHttpsRedirection();
    app.UseCors("MobileClient");
    app.UseRouting();
    app.UseMiddleware<HotelContextMiddleware>();
    app.UseAuthentication();
    app.UseMiddleware<HotelScopeAuthorizationMiddleware>();
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

            if (!builder.Environment.IsDevelopment())
            {
                throw new InvalidOperationException("CORS allowed origins must be configured outside Development.");
            }

            policy.AllowAnyOrigin()
                .AllowAnyHeader()
                .AllowAnyMethod();
        });
    });
}

static void AddSwagger(WebApplicationBuilder builder)
{
    builder.Services.AddSwaggerGen(options =>
    {
        options.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
        {
            Name = "Authorization",
            Type = SecuritySchemeType.Http,
            Scheme = "bearer",
            BearerFormat = "JWT",
            In = ParameterLocation.Header,
            Description = "Enter a valid JWT access token."
        });

        options.AddSecurityRequirement(new OpenApiSecurityRequirement
        {
            {
                new OpenApiSecurityScheme
                {
                    Reference = new OpenApiReference
                    {
                        Type = ReferenceType.SecurityScheme,
                        Id = "Bearer"
                    }
                },
                Array.Empty<string>()
            }
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
                ClockSkew = TimeSpan.FromMinutes(1),
                NameClaimType = SecurityClaimTypes.UserId,
                RoleClaimType = SecurityClaimTypes.Role
            };
        });
}

static void AddAuthorization(WebApplicationBuilder builder)
{
    builder.Services.AddAuthorization(options =>
    {
        options.AddPolicy(AuthorizationPolicies.HotelScoped, policy =>
        {
            policy.RequireAuthenticatedUser();
            policy.Requirements.Add(new HotelScopedRequirement());
        });
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
        "PAYOS_BASE_URL" => "PayOs:BaseUrl",
        "PAYOS_RETURN_URL" => "PayOs:ReturnUrl",
        "PAYOS_CANCEL_URL" => "PayOs:CancelUrl",
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

public partial class Program
{
}
