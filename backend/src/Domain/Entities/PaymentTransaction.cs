using HotelMarketplace.Domain.Common;
using HotelMarketplace.Domain.Enums;

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

    public decimal Amount { get; private set; }

    public PaymentStatus Status { get; private set; }

    public ReconciliationStatus ReconciliationStatus { get; private set; }

    public DateTime CreatedAtUtc { get; private set; }
}
