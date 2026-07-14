using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.Authentication;

public sealed record RegisterRequest(
    string Email,
    string Password,
    string FullName,
    string? PhoneNumber,
    UserRoleCode Role);
