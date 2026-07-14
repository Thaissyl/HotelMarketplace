using HotelMarketplace.Domain.Common;
using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Domain.Entities;

public sealed class BookingRoomAssignment : Entity, IHotelScopedEntity
{
    private BookingRoomAssignment()
    {
    }

    public BookingRoomAssignment(Guid id, Guid hotelId, Guid bookingId, Guid bookingRoomId, Guid physicalRoomId, DateOnly startDate, DateOnly endDate, Guid assignedByUserAccountId)
        : base(id)
    {
        Guard.NotEmpty(hotelId, nameof(HotelId));
        Guard.NotEmpty(bookingId, nameof(BookingId));
        Guard.NotEmpty(bookingRoomId, nameof(BookingRoomId));
        Guard.NotEmpty(physicalRoomId, nameof(PhysicalRoomId));
        Guard.NotEmpty(assignedByUserAccountId, nameof(AssignedByUserAccountId));
        Guard.DateRange(startDate, endDate, "BookingRoomAssignment.InvalidDateRange");
        HotelId = hotelId;
        BookingId = bookingId;
        BookingRoomId = bookingRoomId;
        PhysicalRoomId = physicalRoomId;
        StartDate = startDate;
        EndDate = endDate;
        AssignedByUserAccountId = assignedByUserAccountId;
        Status = RecordStatus.Active;
        AssignedAtUtc = DateTime.UtcNow;
    }

    public Guid HotelId { get; private set; }

    public Guid BookingId { get; private set; }

    public Guid BookingRoomId { get; private set; }

    public Guid PhysicalRoomId { get; private set; }

    public DateOnly StartDate { get; private set; }

    public DateOnly EndDate { get; private set; }

    public Guid AssignedByUserAccountId { get; private set; }

    public RecordStatus Status { get; private set; }

    public DateTime AssignedAtUtc { get; private set; }

    public void Deactivate()
    {
        Status = RecordStatus.Inactive;
    }
}
