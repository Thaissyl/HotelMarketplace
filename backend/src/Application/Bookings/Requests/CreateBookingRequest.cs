namespace HotelMarketplace.Application.Bookings.Requests;

public sealed record CreateBookingRequest(
    Guid HotelId,
    Guid RoomTypeId,
    DateOnly CheckInDate,
    DateOnly CheckOutDate,
    int RoomCount,
    int GuestCount,
    string GuestFullName,
    string GuestPhone);
