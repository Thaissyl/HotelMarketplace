namespace HotelMarketplace.Application.CustomerEngagement.Dtos;

public sealed record SavedHotelDto(
    Guid HotelId,
    string Name,
    string City,
    string AddressLine,
    decimal MinimumPricePerNight,
    string? CoverImageUrl,
    DateTime SavedAtUtc);
