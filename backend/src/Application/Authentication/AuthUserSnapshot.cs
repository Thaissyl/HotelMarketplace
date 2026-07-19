using HotelMarketplace.Domain.Enums;
using HotelMarketplace.Application.Security;

namespace HotelMarketplace.Application.Authentication;

public sealed record AuthUserSnapshot(
    Guid UserId,
    string Email,
    string PasswordHash,
    AccountStatus Status,
    IReadOnlyCollection<UserRoleCode> Roles,
    IReadOnlyCollection<Guid> HotelIds,
    IReadOnlyCollection<HotelRoleAccess> HotelRoleAccesses);
