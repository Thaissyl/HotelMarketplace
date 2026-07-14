using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.Security;

internal sealed class HotelAccessAuthorizer : IHotelAccessAuthorizer
{
    private readonly ICurrentUserService _currentUserService;

    public HotelAccessAuthorizer(ICurrentUserService currentUserService)
    {
        _currentUserService = currentUserService;
    }

    public bool HasAccess(Guid hotelId)
    {
        if (!_currentUserService.IsAuthenticated)
        {
            return false;
        }

        if (_currentUserService.Roles.Contains(UserRoleCode.PlatformAdministrator))
        {
            return true;
        }

        return _currentUserService.HotelIds.Contains(hotelId);
    }
}
