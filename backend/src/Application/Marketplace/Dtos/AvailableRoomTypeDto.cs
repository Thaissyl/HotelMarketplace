namespace HotelMarketplace.Application.Marketplace.Dtos;

public sealed record AvailableRoomTypeDto(
    Guid Id,
    string Name,
    int AdultCapacity,
    int ChildCapacity,
    int TotalGuestCapacity,
    decimal BasePricePerNight,
    int AvailableRoomCount,
    int RequestedRoomCount,
    int Nights,
    decimal TotalPriceForStay,
    string? Description,
    string? Facilities);
