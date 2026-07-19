using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.Security;

public interface IHotelAccessRepository
{
    Task<IReadOnlyCollection<HotelRoleAccess>> GetActiveAccessesAsync(
        Guid userAccountId,
        CancellationToken cancellationToken);

    Task<bool> HasActiveAccessAsync(
        Guid userAccountId,
        Guid hotelId,
        IReadOnlyCollection<UserRoleCode>? allowedRoles,
        CancellationToken cancellationToken);
}
