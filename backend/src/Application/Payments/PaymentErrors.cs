using HotelMarketplace.SharedKernel.Results;

namespace HotelMarketplace.Application.Payments;

public static class PaymentErrors
{
    public static readonly ResultError Forbidden = new("Payment.Forbidden", "The current user is not allowed to access this booking payment.");
    public static readonly ResultError BookingNotFound = new("Payment.BookingNotFound", "The booking was not found.");
    public static readonly ResultError BookingNotPendingPayment = new("Payment.BookingNotPendingPayment", "The booking is not waiting for payment.");
    public static readonly ResultError PaymentExpired = new("Payment.PaymentExpired", "The payment hold has expired.");
    public static readonly ResultError InvalidAmount = new("Payment.InvalidAmount", "The booking amount is not valid for payOS payment.");
    public static readonly ResultError GatewayRejected = new("Payment.GatewayRejected", "The payment gateway rejected the payment link request.");
    public static readonly ResultError InvalidWebhookRequest = new("Payment.InvalidWebhookRequest", "The payment webhook payload is invalid.");
    public static readonly ResultError InvalidWebhookSignature = new("Payment.InvalidWebhookSignature", "The payment webhook signature is invalid.");
    public static readonly ResultError PaymentTransactionNotFound = new("Payment.TransactionNotFound", "The payment transaction was not found.");
    public static readonly ResultError WebhookAmountMismatch = new("Payment.WebhookAmountMismatch", "The webhook amount does not match the booking payment amount.");
}
