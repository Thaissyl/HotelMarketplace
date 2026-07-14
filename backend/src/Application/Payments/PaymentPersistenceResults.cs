using HotelMarketplace.Application.Payments.Dtos;
using HotelMarketplace.Application.Payments.Models;

namespace HotelMarketplace.Application.Payments;

public sealed record CreatePaymentLinkPersistenceResult(
    CreatePaymentLinkPersistenceStatus Status,
    PreparedPaymentLink? PreparedPaymentLink,
    PaymentLinkDto? ExistingPaymentLink)
{
    public static CreatePaymentLinkPersistenceResult Prepared(PreparedPaymentLink preparedPaymentLink)
    {
        return new CreatePaymentLinkPersistenceResult(CreatePaymentLinkPersistenceStatus.Prepared, preparedPaymentLink, null);
    }

    public static CreatePaymentLinkPersistenceResult Existing(PaymentLinkDto paymentLink)
    {
        return new CreatePaymentLinkPersistenceResult(CreatePaymentLinkPersistenceStatus.ExistingPaymentLink, null, paymentLink);
    }

    public static CreatePaymentLinkPersistenceResult Failure(CreatePaymentLinkPersistenceStatus status)
    {
        return new CreatePaymentLinkPersistenceResult(status, null, null);
    }
}

public sealed record PreparedPaymentLink(
    Guid PaymentTransactionId,
    Guid BookingId,
    string BookingCode,
    CreatePaymentLinkGatewayRequest GatewayRequest,
    DateTime ExpiresAtUtc);

public enum CreatePaymentLinkPersistenceStatus
{
    Prepared = 1,
    ExistingPaymentLink = 2,
    Forbidden = 3,
    BookingNotFound = 4,
    BookingNotPendingPayment = 5,
    PaymentExpired = 6,
    InvalidAmount = 7
}

public sealed record PaymentWebhookPersistenceResult(
    PaymentWebhookPersistenceStatus Status,
    string Message)
{
    public static PaymentWebhookPersistenceResult Processed(string message)
    {
        return new PaymentWebhookPersistenceResult(PaymentWebhookPersistenceStatus.Processed, message);
    }

    public static PaymentWebhookPersistenceResult Duplicate(string message)
    {
        return new PaymentWebhookPersistenceResult(PaymentWebhookPersistenceStatus.Duplicate, message);
    }

    public static PaymentWebhookPersistenceResult Failure(PaymentWebhookPersistenceStatus status, string message)
    {
        return new PaymentWebhookPersistenceResult(status, message);
    }
}

public enum PaymentWebhookPersistenceStatus
{
    Processed = 1,
    Duplicate = 2,
    TransactionNotFound = 3,
    AmountMismatch = 4,
    PaymentExpired = 5
}

public sealed record SimulatedPaymentPersistenceResult(
    SimulatedPaymentPersistenceStatus Status,
    string Message)
{
    public static SimulatedPaymentPersistenceResult Processed(string message)
    {
        return new SimulatedPaymentPersistenceResult(SimulatedPaymentPersistenceStatus.Processed, message);
    }

    public static SimulatedPaymentPersistenceResult Duplicate(string message)
    {
        return new SimulatedPaymentPersistenceResult(SimulatedPaymentPersistenceStatus.Duplicate, message);
    }

    public static SimulatedPaymentPersistenceResult Failure(SimulatedPaymentPersistenceStatus status, string message)
    {
        return new SimulatedPaymentPersistenceResult(status, message);
    }
}

public enum SimulatedPaymentPersistenceStatus
{
    Processed = 1,
    Duplicate = 2,
    Forbidden = 3,
    BookingNotFound = 4,
    BookingNotPendingPayment = 5,
    PaymentExpired = 6
}
