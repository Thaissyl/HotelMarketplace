using HotelMarketplace.Application.PlatformAdmin.Dtos;

namespace HotelMarketplace.Application.PlatformAdmin;

public enum PlatformAdminPersistenceStatus
{
    Success = 1,
    HotelNotFound = 2,
    InvalidHotelReviewState = 3,
    SettlementNotFound = 4,
    SettlementNotEligible = 5,
    InvalidSettlementStatus = 6,
    RefundNotFound = 7,
    InvalidRefundStatus = 8,
    PaymentTransactionNotFound = 9,
    InvalidReconciliationStatus = 10,
    LockUnavailable = 11
}

public sealed record PlatformAdminHotelResult(PlatformAdminPersistenceStatus Status, AdminHotelDto? Hotel)
{
    public static PlatformAdminHotelResult Success(AdminHotelDto hotel) => new(PlatformAdminPersistenceStatus.Success, hotel);
    public static PlatformAdminHotelResult Failure(PlatformAdminPersistenceStatus status) => new(status, null);
}

public sealed record PlatformAdminSettlementResult(PlatformAdminPersistenceStatus Status, AdminSettlementDto? Settlement)
{
    public static PlatformAdminSettlementResult Success(AdminSettlementDto settlement) => new(PlatformAdminPersistenceStatus.Success, settlement);
    public static PlatformAdminSettlementResult Failure(PlatformAdminPersistenceStatus status) => new(status, null);
}

public sealed record PlatformAdminRefundResult(PlatformAdminPersistenceStatus Status, AdminRefundDto? Refund)
{
    public static PlatformAdminRefundResult Success(AdminRefundDto refund) => new(PlatformAdminPersistenceStatus.Success, refund);
    public static PlatformAdminRefundResult Failure(PlatformAdminPersistenceStatus status) => new(status, null);
}

public sealed record PlatformAdminPaymentResult(PlatformAdminPersistenceStatus Status, AdminPaymentTransactionDto? PaymentTransaction)
{
    public static PlatformAdminPaymentResult Success(AdminPaymentTransactionDto paymentTransaction) => new(PlatformAdminPersistenceStatus.Success, paymentTransaction);
    public static PlatformAdminPaymentResult Failure(PlatformAdminPersistenceStatus status) => new(status, null);
}
