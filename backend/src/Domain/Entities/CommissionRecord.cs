using HotelMarketplace.Domain.Common;
using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Domain.Entities;

public sealed class CommissionRecord : Entity, IHotelScopedEntity
{
    private CommissionRecord()
    {
    }

    public CommissionRecord(
        Guid id,
        Guid hotelId,
        Guid bookingId,
        decimal baseAmount,
        decimal commissionRate,
        CommissionStatus status = CommissionStatus.Deductible)
        : base(id)
    {
        Guard.NotEmpty(hotelId, nameof(HotelId));
        Guard.NotEmpty(bookingId, nameof(BookingId));
        Guard.NonNegative(baseAmount, nameof(BaseAmount));
        Guard.Rate(commissionRate, nameof(CommissionRate), 0.30m);
        HotelId = hotelId;
        BookingId = bookingId;
        BaseAmount = baseAmount;
        CommissionRate = commissionRate;
        CommissionAmount = decimal.Round(baseAmount * commissionRate, 2, MidpointRounding.AwayFromZero);
        Status = status;
        CreatedAtUtc = DateTime.UtcNow;
    }

    public Guid HotelId { get; private set; }

    public Guid BookingId { get; private set; }

    public decimal BaseAmount { get; private set; }

    public decimal CommissionRate { get; private set; }

    public decimal CommissionAmount { get; private set; }

    public CommissionStatus Status { get; private set; }

    public DateTime CreatedAtUtc { get; private set; }

    public void MarkSettled()
    {
        if (Status != CommissionStatus.Deductible)
        {
            throw new SharedKernel.Exceptions.DomainException(
                "CommissionRecord.InvalidStatusForSettlement",
                "Only deductible commission can be settled from platform-collected funds.");
        }

        Status = CommissionStatus.Settled;
    }

    public void MarkCollected()
    {
        if (Status != CommissionStatus.Receivable)
        {
            throw new SharedKernel.Exceptions.DomainException(
                "CommissionRecord.InvalidStatusForCollection",
                "Only receivable commission can be collected from a hotel.");
        }

        Status = CommissionStatus.Collected;
    }

    public void MarkException()
    {
        if (Status is CommissionStatus.Settled or CommissionStatus.Collected)
        {
            throw new SharedKernel.Exceptions.DomainException(
                "CommissionRecord.FinalizedCannotBecomeException",
                "A finalized commission cannot become an exception.");
        }

        Status = CommissionStatus.Exception;
    }
}
