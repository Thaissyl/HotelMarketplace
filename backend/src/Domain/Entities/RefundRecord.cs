using HotelMarketplace.Domain.Common;
using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Domain.Entities;

public sealed class RefundRecord : Entity, IHotelScopedEntity
{
    private RefundRecord()
    {
        Reason = string.Empty;
    }

    public RefundRecord(Guid id, Guid hotelId, Guid bookingId, decimal requestedAmount, string reason)
        : base(id)
    {
        Guard.NotEmpty(hotelId, nameof(HotelId));
        Guard.NotEmpty(bookingId, nameof(BookingId));
        Guard.NonNegative(requestedAmount, nameof(RequestedAmount));
        HotelId = hotelId;
        BookingId = bookingId;
        RequestedAmount = requestedAmount;
        ApprovedAmount = 0m;
        Reason = Guard.NotBlank(reason, nameof(Reason), 500);
        Status = RefundStatus.PendingReview;
        CreatedAtUtc = DateTime.UtcNow;
    }

    public Guid HotelId { get; private set; }

    public Guid BookingId { get; private set; }

    public decimal RequestedAmount { get; private set; }

    public decimal ApprovedAmount { get; private set; }

    public string Reason { get; private set; }

    public RefundStatus Status { get; private set; }

    public DateTime CreatedAtUtc { get; private set; }
}
