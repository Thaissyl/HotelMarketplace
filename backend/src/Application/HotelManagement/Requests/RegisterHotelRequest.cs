namespace HotelMarketplace.Application.HotelManagement.Requests;

public sealed record RegisterHotelRequest(
    string Name,
    string City,
    string AddressLine,
    string ContactEmail,
    string ContactPhone,
    string? Description);
