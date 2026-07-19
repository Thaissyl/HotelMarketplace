using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.Security;

public interface IHotelAccessAuthorizer
{
    Task<IReadOnlyCollection<HotelRoleAccess>> GetActiveAccessesAsync(
        CancellationToken cancellationToken = default);

    Task<bool> HasAccessAsync(
        Guid hotelId,
        IReadOnlyCollection<UserRoleCode>? allowedRoles = null,
        CancellationToken cancellationToken = default);
}
