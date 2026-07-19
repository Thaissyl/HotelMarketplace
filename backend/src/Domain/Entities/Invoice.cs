using HotelMarketplace.Domain.Common;
using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Domain.Entities;

public sealed class Invoice : Entity, IHotelScopedEntity
{
    private Invoice()
    {
        InvoiceNumber = string.Empty;
    }

    public Invoice(
        Guid id,
        Guid hotelId,
        Guid bookingId,
        string invoiceNumber,
        decimal roomAmount,
        decimal paidAmount,
        decimal refundAmount,
        DateTime finalizedAtUtc)
        : base(id)
    {
        Guard.NotEmpty(hotelId, nameof(HotelId));
        Guard.NotEmpty(bookingId, nameof(BookingId));
        Guard.NonNegative(roomAmount, nameof(RoomAmount));
        Guard.NonNegative(paidAmount, nameof(PaidAmount));
        Guard.NonNegative(refundAmount, nameof(RefundAmount));
        decimal balanceAmount = roomAmount - paidAmount + refundAmount;
        if (balanceAmount != 0)
        {
            throw new SharedKernel.Exceptions.DomainException(
                "Invoice.OutstandingBalance",
                "An invoice can be finalized only when its balance is zero.");
        }
        HotelId = hotelId;
        BookingId = bookingId;
        InvoiceNumber = Guard.NotBlank(invoiceNumber, nameof(InvoiceNumber), 32).ToUpperInvariant();
        RoomAmount = roomAmount;
        PaidAmount = paidAmount;
        RefundAmount = refundAmount;
        BalanceAmount = balanceAmount;
        Status = InvoiceStatus.Paid;
        FinalizedAtUtc = EnsureUtc(finalizedAtUtc);
        IssuedAtUtc = FinalizedAtUtc.Value;
    }

    public Guid HotelId { get; private set; }

    public Guid BookingId { get; private set; }

    public string InvoiceNumber { get; private set; }

    public decimal RoomAmount { get; private set; }

    public decimal PaidAmount { get; private set; }

    public decimal RefundAmount { get; private set; }

    public decimal BalanceAmount { get; private set; }

    public InvoiceStatus Status { get; private set; }

    public DateTime IssuedAtUtc { get; private set; }

    public DateTime? FinalizedAtUtc { get; private set; }

    private static DateTime EnsureUtc(DateTime value)
    {
        if (value.Kind == DateTimeKind.Local)
        {
            throw new SharedKernel.Exceptions.DomainException(
                "Invoice.InvalidUtcTimestamp",
                "Invoice finalization time must be expressed in UTC.");
        }

        return DateTime.SpecifyKind(value, DateTimeKind.Utc);
    }
}
