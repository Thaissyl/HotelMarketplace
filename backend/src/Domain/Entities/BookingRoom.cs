using HotelMarketplace.Domain.Common;

namespace HotelMarketplace.Domain.Entities;

public sealed class BookingRoom : Entity
{
    private BookingRoom()
    {
    }

    public BookingRoom(Guid id, Guid bookingId, Guid roomTypeId, int quantity, decimal unitPricePerNight, int nights)
        : base(id)
    {
        Guard.NotEmpty(bookingId, nameof(BookingId));
        Guard.NotEmpty(roomTypeId, nameof(RoomTypeId));
        Guard.GreaterThanZero(quantity, nameof(Quantity));
        Guard.GreaterThanZero(nights, nameof(Nights));
        Guard.NonNegative(unitPricePerNight, nameof(UnitPricePerNight));
        BookingId = bookingId;
        RoomTypeId = roomTypeId;
        Quantity = quantity;
        UnitPricePerNight = unitPricePerNight;
        Nights = nights;
        LineAmount = quantity * nights * unitPricePerNight;
    }

    public Guid BookingId { get; private set; }

    public Guid RoomTypeId { get; private set; }

    public int Quantity { get; private set; }

    public int Nights { get; private set; }

    public decimal UnitPricePerNight { get; private set; }

    public decimal LineAmount { get; private set; }
}
