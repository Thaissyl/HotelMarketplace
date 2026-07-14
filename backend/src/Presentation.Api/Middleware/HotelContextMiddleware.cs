using HotelMarketplace.SharedKernel.Tenancy;
using Microsoft.AspNetCore.Routing;

namespace HotelMarketplace.Presentation.Api.Middleware;

internal sealed class HotelContextMiddleware
{
    private const string HeaderName = "X-Hotel-Id";
    private readonly RequestDelegate _next;

    public HotelContextMiddleware(RequestDelegate next)
    {
        _next = next;
    }

    public async Task InvokeAsync(HttpContext httpContext, CurrentHotelContext currentHotelContext)
    {
        Guid? hotelId = ResolveHotelId(httpContext);

        if (hotelId is null)
        {
            await _next(httpContext);
            return;
        }

        using IDisposable hotelScope = currentHotelContext.UseHotel(hotelId.Value);
        await _next(httpContext);
    }

    private static Guid? ResolveHotelId(HttpContext httpContext)
    {
        object? routeValue = httpContext.GetRouteValue("hotelId");

        if (routeValue is not null && Guid.TryParse(routeValue.ToString(), out Guid routeHotelId))
        {
            return routeHotelId;
        }

        if (httpContext.Request.Headers.TryGetValue(HeaderName, out Microsoft.Extensions.Primitives.StringValues headerValues) &&
            Guid.TryParse(headerValues.FirstOrDefault(), out Guid headerHotelId))
        {
            return headerHotelId;
        }

        if (httpContext.Request.Query.TryGetValue("hotelId", out Microsoft.Extensions.Primitives.StringValues queryValues) &&
            Guid.TryParse(queryValues.FirstOrDefault(), out Guid queryHotelId))
        {
            return queryHotelId;
        }

        return null;
    }
}
