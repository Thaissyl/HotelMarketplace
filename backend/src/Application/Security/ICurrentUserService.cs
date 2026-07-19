using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.Security;

public interface ICurrentUserService
{
    bool IsAuthenticated { get; }

    Guid? UserId { get; }

    string? Email { get; }

    IReadOnlyCollection<UserRoleCode> Roles { get; }

    IReadOnlyCollection<Guid> HotelIds { get; }

    IReadOnlyCollection<HotelRoleAccess> HotelRoleAccesses { get; }
}
