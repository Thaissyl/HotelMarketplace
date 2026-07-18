using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.PlatformAdmin.Dtos;

public sealed record AdminUserDto(
    Guid Id,
    string Email,
    string FullName,
    string? PhoneNumber,
    AccountStatus Status,
    IReadOnlyCollection<UserRoleCode> Roles,
    IReadOnlyCollection<Guid> HotelIds,
    DateTime CreatedAtUtc);
