namespace HotelMarketplace.Application.Marketplace.Requests;

public sealed record HotelDetailAvailabilityRequest(
    DateOnly CheckInDate,
    DateOnly CheckOutDate,
    int GuestCount,
    int RoomCount);
