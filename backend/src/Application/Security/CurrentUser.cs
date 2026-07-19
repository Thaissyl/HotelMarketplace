using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.Security;

public sealed record CurrentUser(
    Guid UserId,
    string Email,
    IReadOnlyCollection<UserRoleCode> Roles,
    IReadOnlyCollection<Guid> HotelIds,
    IReadOnlyCollection<HotelRoleAccess> HotelRoleAccesses);
