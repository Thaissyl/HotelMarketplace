namespace HotelMarketplace.Application.Bookings.Expiration;

public sealed record ExpireUnpaidBookingsResult(
    int ExpiredCount,
    IReadOnlyCollection<ExpiredBookingDto> ExpiredBookings);
