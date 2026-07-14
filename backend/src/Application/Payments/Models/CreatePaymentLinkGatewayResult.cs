namespace HotelMarketplace.Application.Payments.Models;

public sealed record CreatePaymentLinkGatewayResult(
    long OrderCode,
    int Amount,
    string CheckoutUrl,
    string? PaymentLinkId,
    string? QrCode,
    string Status);
