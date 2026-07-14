using HotelMarketplace.Domain.Common;
using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Domain.Entities;

public sealed class PaymentCollectionRecord : Entity, IHotelScopedEntity
{
    private PaymentCollectionRecord()
    {
    }

    public PaymentCollectionRecord(Guid id, Guid hotelId, Guid bookingId, Guid collectedByUserAccountId, decimal amount)
        : base(id)
    {
        Guard.NotEmpty(hotelId, nameof(HotelId));
        Guard.NotEmpty(bookingId, nameof(BookingId));
        Guard.NotEmpty(collectedByUserAccountId, nameof(CollectedByUserAccountId));
        Guard.NonNegative(amount, nameof(Amount));
        HotelId = hotelId;
        BookingId = bookingId;
        CollectedByUserAccountId = collectedByUserAccountId;
        Amount = amount;
        Status = PaymentStatus.Paid;
        CollectedAtUtc = DateTime.UtcNow;
    }

    public Guid HotelId { get; private set; }

    public Guid BookingId { get; private set; }

    public Guid CollectedByUserAccountId { get; private set; }

    public decimal Amount { get; private set; }

    public PaymentStatus Status { get; private set; }

    public DateTime CollectedAtUtc { get; private set; }
}
