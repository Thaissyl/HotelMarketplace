using HotelMarketplace.Application.Payments.Dtos;

namespace HotelMarketplace.Application.Payments;

public sealed record DemoPaymentPersistenceResult(
    DemoPaymentPersistenceStatus Status,
    DemoPaymentResultDto? Payment,
    string Message)
{
    public static DemoPaymentPersistenceResult Processed(DemoPaymentResultDto payment)
    {
        return new DemoPaymentPersistenceResult(
            DemoPaymentPersistenceStatus.Processed,
            payment,
            "Demo payment confirmed the booking.");
    }

    public static DemoPaymentPersistenceResult Duplicate(DemoPaymentResultDto payment)
    {
        return new DemoPaymentPersistenceResult(
            DemoPaymentPersistenceStatus.Duplicate,
            payment,
            "Demo payment was already confirmed.");
    }

    public static DemoPaymentPersistenceResult Failure(
        DemoPaymentPersistenceStatus status,
        string message)
    {
        return new DemoPaymentPersistenceResult(status, null, message);
    }
}

public enum DemoPaymentPersistenceStatus
{
    Processed = 1,
    Duplicate = 2,
    Forbidden = 3,
    BookingNotFound = 4,
    BookingNotPendingPayment = 5,
    PaymentExpired = 6,
    AmountMismatch = 7,
    LockUnavailable = 8
}
