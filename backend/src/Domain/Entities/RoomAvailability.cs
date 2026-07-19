using HotelMarketplace.Domain.Common;
using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Domain.Entities;

public sealed class RoomAvailability : Entity, IHotelScopedEntity
{
    private RoomAvailability()
    {
        Reason = string.Empty;
    }

    public RoomAvailability(
        Guid id,
        Guid hotelId,
        Guid roomTypeId,
        DateOnly startDate,
        DateOnly endDate,
        AvailabilityStatus status,
        Guid? physicalRoomId = null,
        string? reason = null)
        : base(id)
    {
        Guard.NotEmpty(hotelId, nameof(HotelId));
        Guard.NotEmpty(roomTypeId, nameof(RoomTypeId));
        Guard.DateRange(startDate, endDate, "RoomAvailability.InvalidDateRange");
        if (status == AvailabilityStatus.Open)
        {
            throw new SharedKernel.Exceptions.DomainException(
                "RoomAvailability.OpenIntervalsAreNotPersisted",
                "Open availability is represented by the absence of a blocking interval.");
        }

        HotelId = hotelId;
        RoomTypeId = roomTypeId;
        PhysicalRoomId = physicalRoomId;
        StartDate = startDate;
        EndDate = endDate;
        Status = status;
        Reason = Guard.NotBlank(reason ?? string.Empty, nameof(Reason), 500);
    }

    public Guid HotelId { get; private set; }

    public Guid RoomTypeId { get; private set; }

    public Guid? PhysicalRoomId { get; private set; }

    public DateOnly StartDate { get; private set; }

    public DateOnly EndDate { get; private set; }

    public AvailabilityStatus Status { get; private set; }

    public string Reason { get; private set; }
}
