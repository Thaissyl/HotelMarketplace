using HotelMarketplace.Domain.Common;

namespace HotelMarketplace.Domain.Entities;

public sealed class CommissionRecord : Entity, IHotelScopedEntity
{
    private CommissionRecord()
    {
    }

    public CommissionRecord(Guid id, Guid hotelId, Guid bookingId, decimal baseAmount, decimal commissionRate)
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
        CreatedAtUtc = DateTime.UtcNow;
    }

    public Guid HotelId { get; private set; }

    public Guid BookingId { get; private set; }

    public decimal BaseAmount { get; private set; }

    public decimal CommissionRate { get; private set; }

    public decimal CommissionAmount { get; private set; }

    public DateTime CreatedAtUtc { get; private set; }
}
