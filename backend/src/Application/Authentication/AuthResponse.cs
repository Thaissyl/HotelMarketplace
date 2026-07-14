using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.Authentication;

public sealed record AuthResponse(
    Guid UserId,
    string Email,
    IReadOnlyCollection<UserRoleCode> Roles,
    IReadOnlyCollection<Guid> HotelIds,
    string AccessToken,
    DateTime ExpiresAtUtc);
