using HotelMarketplace.Application.Security;
using HotelMarketplace.Domain.Enums;
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

    protected override async Task HandleRequirementAsync(
        AuthorizationHandlerContext context,
        HotelScopedRequirement requirement)
    {
        Guid? hotelId = _currentHotelContext.HotelId;

        if (!hotelId.HasValue)
        {
            return;
        }

        IReadOnlyCollection<UserRoleCode>? allowedRoles = ResolveAllowedHotelRoles(context.Resource);
        CancellationToken cancellationToken = context.Resource is HttpContext httpContext
            ? httpContext.RequestAborted
            : CancellationToken.None;

        if (await _hotelAccessAuthorizer.HasAccessAsync(hotelId.Value, allowedRoles, cancellationToken))
        {
            context.Succeed(requirement);
        }
    }

    private static UserRoleCode[]? ResolveAllowedHotelRoles(object? resource)
    {
        if (resource is not HttpContext httpContext)
        {
            return null;
        }

        UserRoleCode[][] roleGroups = httpContext.GetEndpoint()?.Metadata
            .GetOrderedMetadata<IAuthorizeData>()
            .Where(authorizeData => !string.IsNullOrWhiteSpace(authorizeData.Roles))
            .Select(authorizeData => authorizeData.Roles!
                .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
                .Select(role => Enum.TryParse(role, ignoreCase: false, out UserRoleCode parsedRole)
                    ? parsedRole
                    : (UserRoleCode?)null)
                .Where(role => role.HasValue)
                .Select(role => role!.Value)
                .Distinct()
                .ToArray())
            .Where(group => group.Length > 0)
            .ToArray() ?? Array.Empty<UserRoleCode[]>();

        if (roleGroups.Length == 0)
        {
            return null;
        }

        HashSet<UserRoleCode> compatibleRoles = roleGroups[0].ToHashSet();
        foreach (UserRoleCode[] roleGroup in roleGroups.Skip(1))
        {
            compatibleRoles.IntersectWith(roleGroup);
        }

        return compatibleRoles.ToArray();
    }
}
