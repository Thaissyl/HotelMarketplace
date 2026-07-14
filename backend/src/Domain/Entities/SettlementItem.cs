using HotelMarketplace.Domain.Common;
using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Domain.Entities;

public sealed class SettlementItem : Entity, IHotelScopedEntity
{
    private SettlementItem()
    {
    }

    public SettlementItem(Guid id, Guid hotelId, Guid settlementRecordId, decimal amount, Guid? bookingId = null, Guid? commissionRecordId = null, Guid? paymentTransactionId = null)
        : base(id)
    {
        Guard.NotEmpty(hotelId, nameof(HotelId));
        Guard.NotEmpty(settlementRecordId, nameof(SettlementRecordId));
        Guard.NonNegative(amount, nameof(Amount));
        HotelId = hotelId;
        SettlementRecordId = settlementRecordId;
        BookingId = bookingId;
        CommissionRecordId = commissionRecordId;
        PaymentTransactionId = paymentTransactionId;
        Amount = amount;
        Status = SettlementStatus.Pending;
    }

    public Guid HotelId { get; private set; }

    public Guid SettlementRecordId { get; private set; }

    public Guid? BookingId { get; private set; }

    public Guid? CommissionRecordId { get; private set; }

    public Guid? PaymentTransactionId { get; private set; }

    public decimal Amount { get; private set; }

    public SettlementStatus Status { get; private set; }
}
