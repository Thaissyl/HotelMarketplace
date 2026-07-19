namespace HotelMarketplace.Application.Payments.Dtos;

public sealed record DemoPaymentResultDto(
    string Status,
    string Message,
    Guid PaymentTransactionId,
    string Provider,
    decimal Amount,
    DateTime PaidAtUtc);
