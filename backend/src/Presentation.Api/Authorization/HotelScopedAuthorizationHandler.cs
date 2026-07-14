using HotelMarketplace.Application.Security;
using HotelMarketplace.SharedKernel.Tenancy;
using Microsoft.AspNetCore.Authorization;

namespace HotelMarketplace.Presentation.Api.Authorization;

internal sealed class HotelScopedAuthorizationHandler : AuthorizationHandler<HotelScopedRequirement>
{
    private readonly ICurrentHotelContext _currentHotelContext;
    private readonly IHotelAccessAuthorizer _hotelAccessAuthorizer;

    public HotelScopedAuthorizationHandler(
        ICurrentHotelContext currentHotelContext,
        IHotelAccessAuthorizer hotelAccessAuthorizer)
    {
        _currentHotelContext = currentHotelContext;
        _hotelAccessAuthorizer = hotelAccessAuthorizer;
    }

    protected override Task HandleRequirementAsync(
        AuthorizationHandlerContext context,
        HotelScopedRequirement requirement)
    {
        Guid? hotelId = _currentHotelContext.HotelId;

        if (hotelId.HasValue && _hotelAccessAuthorizer.HasAccess(hotelId.Value))
        {
            context.Succeed(requirement);
        }

        return Task.CompletedTask;
    }
}
