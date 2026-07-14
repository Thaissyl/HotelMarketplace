namespace HotelMarketplace.Application.Payments.Dtos;

public sealed record PaymentLinkDto(
    Guid BookingId,
    string BookingCode,
    long OrderCode,
    decimal Amount,
    string CheckoutUrl,
    string? PaymentLinkId,
    DateTime ExpiresAtUtc);
