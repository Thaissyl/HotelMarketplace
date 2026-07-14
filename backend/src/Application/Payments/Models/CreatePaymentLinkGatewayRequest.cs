namespace HotelMarketplace.Application.Payments.Models;

public sealed record CreatePaymentLinkGatewayRequest(
    long OrderCode,
    int Amount,
    string Description,
    string BuyerName,
    string? BuyerEmail,
    string BuyerPhone,
    DateTime ExpiresAtUtc);
