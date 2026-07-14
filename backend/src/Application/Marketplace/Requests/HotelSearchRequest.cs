namespace HotelMarketplace.Application.Marketplace.Requests;

public sealed record HotelSearchRequest(
    string? Location,
    DateOnly CheckInDate,
    DateOnly CheckOutDate,
    int GuestCount,
    int RoomCount);
