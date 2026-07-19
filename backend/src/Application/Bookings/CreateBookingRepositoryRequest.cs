using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.Bookings;

public sealed record CreateBookingRepositoryRequest(
    Guid CustomerUserAccountId,
    Guid HotelId,
    Guid RoomTypeId,
    DateOnly CheckInDate,
    DateOnly CheckOutDate,
    int RoomCount,
    int GuestCount,
    string GuestFullName,
    string GuestPhone,
    PaymentMode PaymentMode);
