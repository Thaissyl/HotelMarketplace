using HotelMarketplace.Domain.Common;
using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Domain.Entities;

public sealed class Invoice : Entity, IHotelScopedEntity
{
    private Invoice()
    {
        InvoiceNumber = string.Empty;
    }

    public Invoice(Guid id, Guid hotelId, Guid bookingId, string invoiceNumber, decimal roomAmount, decimal paidAmount)
        : base(id)
    {
        Guard.NotEmpty(hotelId, nameof(HotelId));
        Guard.NotEmpty(bookingId, nameof(BookingId));
        Guard.NonNegative(roomAmount, nameof(RoomAmount));
        Guard.NonNegative(paidAmount, nameof(PaidAmount));
        HotelId = hotelId;
        BookingId = bookingId;
        InvoiceNumber = Guard.NotBlank(invoiceNumber, nameof(InvoiceNumber), 32).ToUpperInvariant();
        RoomAmount = roomAmount;
        PaidAmount = paidAmount;
        Status = InvoiceStatus.Issued;
        IssuedAtUtc = DateTime.UtcNow;
    }

    public Guid HotelId { get; private set; }

    public Guid BookingId { get; private set; }

    public string InvoiceNumber { get; private set; }

    public decimal RoomAmount { get; private set; }

    public decimal PaidAmount { get; private set; }

    public InvoiceStatus Status { get; private set; }

    public DateTime IssuedAtUtc { get; private set; }
}
