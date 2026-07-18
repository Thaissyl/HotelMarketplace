using HotelMarketplace.Domain.Common;
using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Domain.Entities;

public sealed class HousekeepingTask : Entity, IHotelScopedEntity
{
    private HousekeepingTask()
    {
        TaskType = string.Empty;
    }

    public HousekeepingTask(Guid id, Guid hotelId, Guid physicalRoomId, string taskType, Guid? bookingId = null, Guid? assignedToUserAccountId = null)
        : base(id)
    {
        Guard.NotEmpty(hotelId, nameof(HotelId));
        Guard.NotEmpty(physicalRoomId, nameof(PhysicalRoomId));
        HotelId = hotelId;
        PhysicalRoomId = physicalRoomId;
        BookingId = bookingId;
        AssignedToUserAccountId = assignedToUserAccountId;
        TaskType = Guard.NotBlank(taskType, nameof(TaskType), 64);
        Status = HousekeepingTaskStatus.Open;
        CreatedAtUtc = DateTime.UtcNow;
    }

    public Guid HotelId { get; private set; }

    public Guid PhysicalRoomId { get; private set; }

    public Guid? BookingId { get; private set; }

    public Guid? AssignedToUserAccountId { get; private set; }

    public string TaskType { get; private set; }

    public HousekeepingTaskStatus Status { get; private set; }

    public DateTime CreatedAtUtc { get; private set; }

    public void Assign(Guid assignedToUserAccountId)
    {
        Guard.NotEmpty(assignedToUserAccountId, nameof(AssignedToUserAccountId));

        if (Status != HousekeepingTaskStatus.Open)
        {
            throw new SharedKernel.Exceptions.DomainException("HousekeepingTask.InvalidAssignStatus", "Only open housekeeping tasks can be assigned.");
        }

        AssignedToUserAccountId = assignedToUserAccountId;
    }

    public void Start(Guid assignedToUserAccountId)
    {
        Guard.NotEmpty(assignedToUserAccountId, nameof(AssignedToUserAccountId));

        if (Status != HousekeepingTaskStatus.Open)
        {
            throw new SharedKernel.Exceptions.DomainException("HousekeepingTask.InvalidStartStatus", "Only open housekeeping tasks can be started.");
        }

        AssignedToUserAccountId = assignedToUserAccountId;
        Status = HousekeepingTaskStatus.InProgress;
    }

    public void Complete()
    {
        if (Status != HousekeepingTaskStatus.InProgress)
        {
            throw new SharedKernel.Exceptions.DomainException("HousekeepingTask.InvalidCompleteStatus", "Only in-progress housekeeping tasks can be completed.");
        }

        Status = HousekeepingTaskStatus.Completed;
    }
}
