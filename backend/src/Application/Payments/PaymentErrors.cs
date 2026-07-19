using HotelMarketplace.SharedKernel.Results;

namespace HotelMarketplace.Application.Payments;

public static class PaymentErrors
{
    public static readonly ResultError Forbidden = new("Payment.Forbidden", "The current user is not allowed to access this booking payment.");
    public static readonly ResultError BookingNotFound = new("Payment.BookingNotFound", "The booking was not found.");
    public static readonly ResultError BookingNotPendingPayment = new("Payment.BookingNotPendingPayment", "The booking is not waiting for payment.");
    public static readonly ResultError PaymentExpired = new("Payment.PaymentExpired", "The payment hold has expired.");
    public static readonly ResultError InvalidAmount = new("Payment.InvalidAmount", "Demo payment amount must be greater than zero.");
    public static readonly ResultError AmountMismatch = new("Payment.AmountMismatch", "Demo payment amount does not match the server-calculated booking total.");
    public static readonly ResultError LockUnavailable = new("Payment.LockUnavailable", "Demo payment is already being processed. Please try again.");
}
