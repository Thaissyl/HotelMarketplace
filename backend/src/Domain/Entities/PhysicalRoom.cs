using HotelMarketplace.Domain.Common;
using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Domain.Entities;

public sealed class PhysicalRoom : Entity, IHotelScopedEntity
{
    private PhysicalRoom()
    {
        RoomNumber = string.Empty;
    }

    public PhysicalRoom(Guid id, Guid hotelId, Guid roomTypeId, string roomNumber)
        : base(id)
    {
        Guard.NotEmpty(hotelId, nameof(HotelId));
        Guard.NotEmpty(roomTypeId, nameof(RoomTypeId));
        HotelId = hotelId;
        RoomTypeId = roomTypeId;
        RoomNumber = Guard.NotBlank(roomNumber, nameof(RoomNumber), 32);
        Status = RoomOperationalStatus.Available;
    }

    public Guid HotelId { get; private set; }

    public Guid RoomTypeId { get; private set; }

    public string RoomNumber { get; private set; }

    public RoomOperationalStatus Status { get; private set; }
}
