using HotelMarketplace.Application.Security;
using HotelMarketplace.SharedKernel.Tenancy;
using Microsoft.AspNetCore.Authorization;

namespace HotelMarketplace.Presentation.Api.Middleware;

internal sealed class HotelScopeAuthorizationMiddleware
{
    private readonly RequestDelegate _next;

    public HotelScopeAuthorizationMiddleware(RequestDelegate next)
    {
        _next = next;
    }

    public async Task InvokeAsync(
        HttpContext httpContext,
        ICurrentHotelContext currentHotelContext,
        IHotelAccessAuthorizer hotelAccessAuthorizer)
    {
        Guid? hotelId = currentHotelContext.HotelId;

        if (hotelId is null || IsAnonymousEndpoint(httpContext))
        {
            await _next(httpContext);
            return;
        }

        if (httpContext.User.Identity?.IsAuthenticated != true)
        {
            httpContext.Response.StatusCode = StatusCodes.Status401Unauthorized;
            return;
        }

        if (!hotelAccessAuthorizer.HasAccess(hotelId.Value))
        {
            httpContext.Response.StatusCode = StatusCodes.Status403Forbidden;
            return;
        }

        await _next(httpContext);
    }

    private static bool IsAnonymousEndpoint(HttpContext httpContext)
    {
        return httpContext.GetEndpoint()?.Metadata.GetMetadata<IAllowAnonymous>() is not null;
    }
}
