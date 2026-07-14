using HotelMarketplace.Domain.Common;
using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Domain.Entities;

public sealed class RoomStatusHistory : Entity, IHotelScopedEntity
{
    private RoomStatusHistory()
    {
    }

    public RoomStatusHistory(Guid id, Guid hotelId, Guid physicalRoomId, RoomOperationalStatus oldStatus, RoomOperationalStatus newStatus, Guid? changedByUserAccountId = null)
        : base(id)
    {
        Guard.NotEmpty(hotelId, nameof(HotelId));
        Guard.NotEmpty(physicalRoomId, nameof(PhysicalRoomId));
        HotelId = hotelId;
        PhysicalRoomId = physicalRoomId;
        OldStatus = oldStatus;
        NewStatus = newStatus;
        ChangedByUserAccountId = changedByUserAccountId;
        ChangedAtUtc = DateTime.UtcNow;
    }

    public Guid HotelId { get; private set; }

    public Guid PhysicalRoomId { get; private set; }

    public RoomOperationalStatus OldStatus { get; private set; }

    public RoomOperationalStatus NewStatus { get; private set; }

    public Guid? ChangedByUserAccountId { get; private set; }

    public DateTime ChangedAtUtc { get; private set; }
}
