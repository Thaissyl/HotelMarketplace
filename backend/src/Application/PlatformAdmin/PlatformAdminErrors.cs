using HotelMarketplace.SharedKernel.Results;

namespace HotelMarketplace.Application.PlatformAdmin;

public static class PlatformAdminErrors
{
    public static readonly ResultError Forbidden = new("PlatformAdmin.Forbidden", "Only Platform Administrator can access this operation.");
    public static readonly ResultError UserNotFound = new("PlatformAdmin.UserNotFound", "The user account was not found.");
    public static readonly ResultError InvalidUserStatus = new("PlatformAdmin.InvalidUserStatus", "The selected user status transition is not allowed.");
    public static readonly ResultError HotelNotFound = new("PlatformAdmin.HotelNotFound", "The hotel was not found.");
    public static readonly ResultError InvalidHotelReviewState = new("PlatformAdmin.InvalidHotelReviewState", "Only hotels pending review can be reviewed.");
    public static readonly ResultError SettlementNotFound = new("PlatformAdmin.SettlementNotFound", "The settlement record was not found.");
    public static readonly ResultError SettlementNotEligible = new("PlatformAdmin.SettlementNotEligible", "No eligible records were found for settlement.");
    public static readonly ResultError InvalidSettlementStatus = new("PlatformAdmin.InvalidSettlementStatus", "The selected settlement status transition is not allowed.");
    public static readonly ResultError RefundNotFound = new("PlatformAdmin.RefundNotFound", "The refund request was not found.");
    public static readonly ResultError InvalidRefundStatus = new("PlatformAdmin.InvalidRefundStatus", "The selected refund status transition is not allowed.");
    public static readonly ResultError PaymentTransactionNotFound = new("PlatformAdmin.PaymentTransactionNotFound", "The payment transaction was not found.");
    public static readonly ResultError InvalidReconciliationStatus = new("PlatformAdmin.InvalidReconciliationStatus", "The selected reconciliation status transition is not allowed.");
    public static readonly ResultError LockUnavailable = new("PlatformAdmin.LockUnavailable", "The admin operation is busy. Please try again.");
}
