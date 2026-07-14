namespace HotelMarketplace.Application.Marketplace.Dtos;

public sealed record HotelDetailDto(
    Guid Id,
    string Name,
    string City,
    string AddressLine,
    string? Description,
    string ContactEmail,
    string ContactPhone,
    DateOnly CheckInDate,
    DateOnly CheckOutDate,
    int GuestCount,
    int RoomCount,
    IReadOnlyCollection<AvailableRoomTypeDto> AvailableRoomTypes);
