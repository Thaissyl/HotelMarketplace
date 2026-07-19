using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.Security;

internal sealed class HotelAccessAuthorizer : IHotelAccessAuthorizer
{
    private readonly ICurrentUserService _currentUserService;
    private readonly IHotelAccessRepository _hotelAccessRepository;

    public HotelAccessAuthorizer(
        ICurrentUserService currentUserService,
        IHotelAccessRepository hotelAccessRepository)
    {
        _currentUserService = currentUserService;
        _hotelAccessRepository = hotelAccessRepository;
    }

    public Task<bool> HasAccessAsync(
        Guid hotelId,
        IReadOnlyCollection<UserRoleCode>? allowedRoles = null,
        CancellationToken cancellationToken = default)
    {
        if (!_currentUserService.IsAuthenticated || _currentUserService.UserId is null)
        {
            return Task.FromResult(false);
        }

        return _hotelAccessRepository.HasActiveAccessAsync(
            _currentUserService.UserId.Value,
            hotelId,
            allowedRoles,
            cancellationToken);
    }

    public Task<IReadOnlyCollection<HotelRoleAccess>> GetActiveAccessesAsync(
        CancellationToken cancellationToken = default)
    {
        if (!_currentUserService.IsAuthenticated || _currentUserService.UserId is null)
        {
            return Task.FromResult<IReadOnlyCollection<HotelRoleAccess>>(Array.Empty<HotelRoleAccess>());
        }

        return _hotelAccessRepository.GetActiveAccessesAsync(
            _currentUserService.UserId.Value,
            cancellationToken);
    }
}
