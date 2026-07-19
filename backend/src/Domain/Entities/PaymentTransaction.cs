using HotelMarketplace.Domain.Common;
using HotelMarketplace.Domain.Enums;
using HotelMarketplace.SharedKernel.Exceptions;

namespace HotelMarketplace.Domain.Entities;

public sealed class PaymentTransaction : Entity, IHotelScopedEntity
{
    private PaymentTransaction()
    {
        Provider = string.Empty;
    }

    public PaymentTransaction(Guid id, Guid hotelId, Guid bookingId, string provider, decimal amount)
        : base(id)
    {
        Guard.NotEmpty(hotelId, nameof(HotelId));
        Guard.NotEmpty(bookingId, nameof(BookingId));
        Guard.NonNegative(amount, nameof(Amount));
        HotelId = hotelId;
        BookingId = bookingId;
        Provider = Guard.NotBlank(provider, nameof(Provider), 64);
        Amount = amount;
        Status = PaymentStatus.Pending;
        ReconciliationStatus = ReconciliationStatus.Unreconciled;
        CreatedAtUtc = DateTime.UtcNow;
    }

    public Guid HotelId { get; private set; }

    public Guid BookingId { get; private set; }

    public string Provider { get; private set; }

    public string? GatewayReference { get; private set; }

    public string? GatewayTransactionReference { get; private set; }

    public decimal Amount { get; private set; }

    public PaymentStatus Status { get; private set; }

    public ReconciliationStatus ReconciliationStatus { get; private set; }

    public DateTime CreatedAtUtc { get; private set; }

    public DateTime? PaidAtUtc { get; private set; }

    public string? ReconciliationNote { get; private set; }

    public DateTime? ReconciledAtUtc { get; private set; }

    public void ReserveGatewayReference(string gatewayReference)
    {
        if (Status != PaymentStatus.Pending)
        {
            throw new DomainException("PaymentTransaction.InvalidStatusForGatewayReference", "Only pending transactions can reserve a payment gateway reference.");
        }

        GatewayReference = Guard.NotBlank(gatewayReference, nameof(GatewayReference), 128);
        Status = PaymentStatus.Processing;
    }

    public void MarkPaid(string gatewayTransactionReference, DateTime paidAtUtc)
    {
        if (Status == PaymentStatus.Paid)
        {
            return;
        }

        if (Status is PaymentStatus.Cancelled or PaymentStatus.Failed)
        {
            throw new DomainException("PaymentTransaction.InvalidStatusForPaid", "A cancelled or failed transaction cannot be marked as paid.");
        }

        GatewayTransactionReference = Guard.NotBlank(gatewayTransactionReference, nameof(GatewayTransactionReference), 128);
        Status = PaymentStatus.Paid;
        ReconciliationStatus = ReconciliationStatus.Unreconciled;
        PaidAtUtc = paidAtUtc;
    }

    public void MarkFailed()
    {
        if (Status == PaymentStatus.Paid)
        {
            return;
        }

        Status = PaymentStatus.Failed;
    }

    public void MarkReconciled(DateTime reconciledAtUtc, string? note)
    {
        if (Status != PaymentStatus.Paid)
        {
            throw new DomainException("PaymentTransaction.InvalidStatusForReconciliation", "Only paid transactions can be reconciled.");
        }

        if (ReconciliationStatus == ReconciliationStatus.Reconciled)
        {
            return;
        }

        if (ReconciliationStatus != ReconciliationStatus.Unreconciled)
        {
            throw new DomainException("PaymentTransaction.ReconciliationFinalized", "A finalized reconciliation result cannot be changed.");
        }

        ReconciliationStatus = ReconciliationStatus.Reconciled;
        ReconciliationNote = Guard.Optional(note, nameof(ReconciliationNote), 1000);
        ReconciledAtUtc = EnsureUtc(reconciledAtUtc);
    }

    public void MarkReconciliationException(string note, DateTime reconciledAtUtc)
    {
        if (Status != PaymentStatus.Paid)
        {
            throw new DomainException("PaymentTransaction.InvalidStatusForReconciliation", "Only paid transactions can be reviewed for reconciliation.");
        }

        if (ReconciliationStatus == ReconciliationStatus.Exception)
        {
            return;
        }

        if (ReconciliationStatus != ReconciliationStatus.Unreconciled)
        {
            throw new DomainException("PaymentTransaction.ReconciliationFinalized", "A finalized reconciliation result cannot be changed.");
        }

        ReconciliationStatus = ReconciliationStatus.Exception;
        ReconciliationNote = Guard.NotBlank(note, nameof(ReconciliationNote), 1000);
        ReconciledAtUtc = EnsureUtc(reconciledAtUtc);
    }

    private static DateTime EnsureUtc(DateTime value)
    {
        if (value.Kind == DateTimeKind.Local)
        {
            throw new DomainException("PaymentTransaction.InvalidUtcTimestamp", "Reconciliation time must be expressed in UTC.");
        }

        return DateTime.SpecifyKind(value, DateTimeKind.Utc);
    }
}
