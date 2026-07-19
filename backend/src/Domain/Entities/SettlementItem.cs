using HotelMarketplace.Domain.Common;
using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Domain.Entities;

public sealed class SettlementItem : Entity, IHotelScopedEntity
{
    private SettlementItem()
    {
    }

    public SettlementItem(
        Guid id,
        Guid hotelId,
        Guid settlementRecordId,
        Guid bookingId,
        Guid commissionRecordId,
        PaymentMode paymentMode,
        BookingStatus bookingStatus,
        decimal grossAmount,
        decimal refundAmount,
        decimal commissionAmount,
        decimal amount,
        Guid? paymentTransactionId = null,
        Guid? paymentCollectionRecordId = null)
        : base(id)
    {
        Guard.NotEmpty(hotelId, nameof(HotelId));
        Guard.NotEmpty(settlementRecordId, nameof(SettlementRecordId));
        Guard.NotEmpty(bookingId, nameof(BookingId));
        Guard.NotEmpty(commissionRecordId, nameof(CommissionRecordId));
        Guard.NonNegative(grossAmount, nameof(GrossAmount));
        Guard.NonNegative(refundAmount, nameof(RefundAmount));
        Guard.NonNegative(commissionAmount, nameof(CommissionAmount));
        Guard.NonNegative(amount, nameof(Amount));
        HotelId = hotelId;
        SettlementRecordId = settlementRecordId;
        BookingId = bookingId;
        CommissionRecordId = commissionRecordId;
        PaymentTransactionId = paymentTransactionId;
        PaymentCollectionRecordId = paymentCollectionRecordId;
        PaymentMode = paymentMode;
        BookingStatus = bookingStatus;
        GrossAmount = grossAmount;
        RefundAmount = refundAmount;
        CommissionAmount = commissionAmount;
        Amount = amount;
        Status = SettlementStatus.Pending;
    }

    public Guid HotelId { get; private set; }

    public Guid SettlementRecordId { get; private set; }

    public Guid? BookingId { get; private set; }

    public Guid? CommissionRecordId { get; private set; }

    public Guid? PaymentTransactionId { get; private set; }

    public Guid? PaymentCollectionRecordId { get; private set; }

    public PaymentMode PaymentMode { get; private set; }

    public BookingStatus BookingStatus { get; private set; }

    public decimal GrossAmount { get; private set; }

    public decimal RefundAmount { get; private set; }

    public decimal CommissionAmount { get; private set; }

    public decimal Amount { get; private set; }

    public SettlementStatus Status { get; private set; }

    public void MarkSettled()
    {
        if (Status != SettlementStatus.Pending)
        {
            throw new SharedKernel.Exceptions.DomainException("SettlementItem.InvalidStatusForSettlement", "Only pending settlement items can be marked as settled.");
        }

        Status = SettlementStatus.Settled;
    }

    public void MarkCollected()
    {
        if (Status != SettlementStatus.Pending)
        {
            throw new SharedKernel.Exceptions.DomainException("SettlementItem.InvalidStatusForCollection", "Only pending settlement items can be collected.");
        }

        Status = SettlementStatus.Collected;
    }

    public void MarkException()
    {
        if (Status is SettlementStatus.Settled or SettlementStatus.Collected)
        {
            throw new SharedKernel.Exceptions.DomainException("SettlementItem.FinalizedCannotBecomeException", "Finalized settlement items cannot be changed to exception.");
        }

        Status = SettlementStatus.Exception;
    }
}
