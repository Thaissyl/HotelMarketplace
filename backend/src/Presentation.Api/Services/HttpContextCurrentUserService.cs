using HotelMarketplace.Application.Security;
using HotelMarketplace.Domain.Enums;
using System.Security.Claims;

namespace HotelMarketplace.Presentation.Api.Services;

internal sealed class HttpContextCurrentUserService : ICurrentUserService
{
    private readonly IHttpContextAccessor _httpContextAccessor;

    public HttpContextCurrentUserService(IHttpContextAccessor httpContextAccessor)
    {
        _httpContextAccessor = httpContextAccessor;
    }

    public bool IsAuthenticated => _httpContextAccessor.HttpContext?.User.Identity?.IsAuthenticated == true;

    public Guid? UserId
    {
        get
        {
            string? userIdValue = _httpContextAccessor.HttpContext?.User.FindFirstValue(SecurityClaimTypes.UserId);
            return Guid.TryParse(userIdValue, out Guid userId) ? userId : null;
        }
    }

    public string? Email => _httpContextAccessor.HttpContext?.User.FindFirstValue(SecurityClaimTypes.Email);

    public IReadOnlyCollection<UserRoleCode> Roles
    {
        get
        {
            ClaimsPrincipal? user = _httpContextAccessor.HttpContext?.User;

            if (user is null)
            {
                return Array.Empty<UserRoleCode>();
            }

            return user.FindAll(SecurityClaimTypes.Role)
                .Select(claim => Enum.TryParse(claim.Value, ignoreCase: false, out UserRoleCode role) ? role : (UserRoleCode?)null)
                .Where(role => role.HasValue)
                .Select(role => role!.Value)
                .Distinct()
                .ToArray();
        }
    }

    public IReadOnlyCollection<Guid> HotelIds
    {
        get
        {
            ClaimsPrincipal? user = _httpContextAccessor.HttpContext?.User;

            if (user is null)
            {
                return Array.Empty<Guid>();
            }

            return user.FindAll(SecurityClaimTypes.HotelId)
                .Select(claim => Guid.TryParse(claim.Value, out Guid hotelId) ? hotelId : (Guid?)null)
                .Where(hotelId => hotelId.HasValue)
                .Select(hotelId => hotelId!.Value)
                .Distinct()
                .ToArray();
        }
    }

    public IReadOnlyCollection<HotelRoleAccess> HotelRoleAccesses
    {
        get
        {
            ClaimsPrincipal? user = _httpContextAccessor.HttpContext?.User;

            if (user is null)
            {
                return Array.Empty<HotelRoleAccess>();
            }

            return user.FindAll(SecurityClaimTypes.HotelRoleAccess)
                .Select(claim => ParseHotelRoleAccess(claim.Value))
                .Where(access => access is not null)
                .Select(access => access!)
                .Distinct()
                .ToArray();
        }
    }

    private static HotelRoleAccess? ParseHotelRoleAccess(string value)
    {
        string[] parts = value.Split('|', 2, StringSplitOptions.TrimEntries);

        return parts.Length == 2 &&
            Guid.TryParse(parts[0], out Guid hotelId) &&
            Enum.TryParse(parts[1], ignoreCase: false, out UserRoleCode role)
                ? new HotelRoleAccess(hotelId, role)
                : null;
    }
}
