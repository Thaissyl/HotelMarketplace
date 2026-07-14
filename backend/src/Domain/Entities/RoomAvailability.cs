using HotelMarketplace.Domain.Common;
using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Domain.Entities;

public sealed class RoomAvailability : Entity, IHotelScopedEntity
{
    private RoomAvailability()
    {
    }

    public RoomAvailability(Guid id, Guid hotelId, Guid roomTypeId, DateOnly startDate, DateOnly endDate, AvailabilityStatus status, Guid? physicalRoomId = null)
        : base(id)
    {
        Guard.NotEmpty(hotelId, nameof(HotelId));
        Guard.NotEmpty(roomTypeId, nameof(RoomTypeId));
        Guard.DateRange(startDate, endDate, "RoomAvailability.InvalidDateRange");
        HotelId = hotelId;
        RoomTypeId = roomTypeId;
        PhysicalRoomId = physicalRoomId;
        StartDate = startDate;
        EndDate = endDate;
        Status = status;
    }

    public Guid HotelId { get; private set; }

    public Guid RoomTypeId { get; private set; }

    public Guid? PhysicalRoomId { get; private set; }

    public DateOnly StartDate { get; private set; }

    public DateOnly EndDate { get; private set; }

    public AvailabilityStatus Status { get; private set; }
}
