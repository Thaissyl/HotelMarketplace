namespace HotelMarketplace.Application.Payments.Models;

public sealed record PaymentWebhookRequest(
    string Code,
    string Desc,
    bool Success,
    PaymentWebhookData Data,
    string Signature);

public sealed record PaymentWebhookData(
    long OrderCode,
    int Amount,
    string Description,
    string AccountNumber,
    string Reference,
    string TransactionDateTime,
    string Currency,
    string PaymentLinkId,
    string Code,
    string Desc,
    string? CounterAccountBankId,
    string? CounterAccountBankName,
    string? CounterAccountName,
    string? CounterAccountNumber,
    string? VirtualAccountName,
    string? VirtualAccountNumber);
