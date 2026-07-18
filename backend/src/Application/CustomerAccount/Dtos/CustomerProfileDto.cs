namespace HotelMarketplace.Application.CustomerAccount.Dtos;

public sealed record CustomerProfileDto(
    Guid UserId,
    string Email,
    string FullName,
    string? PhoneNumber);
