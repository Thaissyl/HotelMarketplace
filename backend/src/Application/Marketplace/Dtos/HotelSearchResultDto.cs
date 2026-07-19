namespace HotelMarketplace.Application.Marketplace.Dtos;

public sealed record HotelSearchResultDto(
    Guid Id,
    string Name,
    string City,
    string AddressLine,
    string? Description,
    string? CoverImageUrl,
    IReadOnlyCollection<string> AmenityNames,
    decimal MinimumPricePerNight,
    int AvailableRoomTypeCount);
