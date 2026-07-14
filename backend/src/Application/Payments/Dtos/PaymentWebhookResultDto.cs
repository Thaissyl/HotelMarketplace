namespace HotelMarketplace.Application.Payments.Dtos;

public sealed record PaymentWebhookResultDto(
    string Status,
    string Message);
