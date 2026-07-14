namespace HotelMarketplace.Application.HotelManagement.Requests;

public sealed record UpdateHotelProfileRequest(
    string Name,
    string City,
    string AddressLine,
    string ContactEmail,
    string ContactPhone,
    string? Description);
