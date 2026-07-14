namespace HotelMarketplace.Application.Bookings.Expiration;

public sealed record ExpiredBookingDto(
    Guid BookingId,
    string BookingCode,
    Guid HotelId,
    DateTime PaymentExpiresAtUtc);
