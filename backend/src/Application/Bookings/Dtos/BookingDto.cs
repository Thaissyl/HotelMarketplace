using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.Bookings.Dtos;

public sealed record BookingDto(
    Guid Id,
    string BookingCode,
    Guid HotelId,
    Guid RoomTypeId,
    DateOnly CheckInDate,
    DateOnly CheckOutDate,
    int RoomCount,
    int GuestCount,
    int Nights,
    decimal UnitPricePerNight,
    decimal TotalAmount,
    BookingStatus Status,
    DateTime CreatedAtUtc,
    DateTime? PaymentExpiresAtUtc,
    string GuestFullName,
    string GuestPhone);
