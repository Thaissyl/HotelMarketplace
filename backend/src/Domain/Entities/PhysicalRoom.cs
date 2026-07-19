using HotelMarketplace.Domain.Common;
using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Domain.Entities;

public sealed class PhysicalRoom : Entity, IHotelScopedEntity
{
    private PhysicalRoom()
    {
        RoomNumber = string.Empty;
    }

    public PhysicalRoom(Guid id, Guid hotelId, Guid roomTypeId, string roomNumber, RoomOperationalStatus initialStatus = RoomOperationalStatus.Available)
        : base(id)
    {
        Guard.NotEmpty(hotelId, nameof(HotelId));
        Guard.NotEmpty(roomTypeId, nameof(RoomTypeId));
        HotelId = hotelId;
        RoomTypeId = roomTypeId;
        RoomNumber = Guard.NotBlank(roomNumber, nameof(RoomNumber), 32);
        Status = initialStatus is RoomOperationalStatus.Available or RoomOperationalStatus.Inactive
            ? initialStatus
            : throw new SharedKernel.Exceptions.DomainException("PhysicalRoom.InvalidInitialStatus", "Initial room status must be Available or Inactive.");
    }

    public Guid HotelId { get; private set; }

    public Guid RoomTypeId { get; private set; }

    public string RoomNumber { get; private set; }

    public RoomOperationalStatus Status { get; private set; }

    public void Rename(string roomNumber)
    {
        RoomNumber = Guard.NotBlank(roomNumber, nameof(RoomNumber), 32);
    }

    public void ChangeSetupStatus(RoomOperationalStatus status)
    {
        if (status is not (RoomOperationalStatus.Available or RoomOperationalStatus.Inactive))
        {
            throw new SharedKernel.Exceptions.DomainException("PhysicalRoom.InvalidSetupStatus", "Setup may only activate or deactivate a room.");
        }

        if (Status != status && Status is not (RoomOperationalStatus.Available or RoomOperationalStatus.Inactive))
        {
            throw new SharedKernel.Exceptions.DomainException("PhysicalRoom.OperationalStatusCannotBeOverridden", "An operational room status cannot be changed through hotel setup.");
        }

        Status = status;
    }

    public void AssignForStay()
    {
        if (Status != RoomOperationalStatus.Available)
        {
            throw new SharedKernel.Exceptions.DomainException("PhysicalRoom.NotAvailableForAssignment", "Selected physical room is not available for assignment.");
        }

        Status = RoomOperationalStatus.Assigned;
    }

    public void ReleaseAssignment()
    {
        if (Status != RoomOperationalStatus.Assigned)
        {
            throw new SharedKernel.Exceptions.DomainException(
                "PhysicalRoom.InvalidAssignmentReleaseStatus",
                "Only an assigned room can be released to available status.");
        }

        Status = RoomOperationalStatus.Available;
    }

    public void MarkOccupiedForCheckIn()
    {
        if (Status is not (RoomOperationalStatus.Available or RoomOperationalStatus.Assigned))
        {
            throw new SharedKernel.Exceptions.DomainException("PhysicalRoom.NotAvailableForCheckIn", "Selected physical room cannot be occupied for check-in.");
        }

        Status = RoomOperationalStatus.Occupied;
    }

    public void ReleaseToHousekeeping()
    {
        if (Status != RoomOperationalStatus.Occupied)
        {
            throw new SharedKernel.Exceptions.DomainException("PhysicalRoom.InvalidCheckoutStatus", "Only occupied rooms can be released to housekeeping.");
        }

        Status = RoomOperationalStatus.Dirty;
    }

    public void StartHousekeeping()
    {
        if (Status != RoomOperationalStatus.Dirty && Status != RoomOperationalStatus.InspectionRequired)
        {
            throw new SharedKernel.Exceptions.DomainException("PhysicalRoom.InvalidHousekeepingStartStatus", "Only dirty or inspection-required rooms can enter cleaning.");
        }

        Status = RoomOperationalStatus.Cleaning;
    }

    public void CompleteHousekeeping(bool requiresInspection)
    {
        if (Status != RoomOperationalStatus.Cleaning)
        {
            throw new SharedKernel.Exceptions.DomainException("PhysicalRoom.InvalidHousekeepingCompleteStatus", "Only rooms in cleaning can become available.");
        }

        Status = requiresInspection
            ? RoomOperationalStatus.InspectionRequired
            : RoomOperationalStatus.Available;
    }

    public void CompleteInspection()
    {
        if (Status != RoomOperationalStatus.InspectionRequired)
        {
            throw new SharedKernel.Exceptions.DomainException("PhysicalRoom.InvalidInspectionStatus", "Only a room awaiting inspection can be released as available.");
        }

        Status = RoomOperationalStatus.Available;
    }

    public void BlockForMaintenance(RoomOperationalStatus blockedStatus)
    {
        if (blockedStatus is not (RoomOperationalStatus.Maintenance or RoomOperationalStatus.OutOfService))
        {
            throw new SharedKernel.Exceptions.DomainException("PhysicalRoom.InvalidMaintenanceBlockStatus", "Maintenance issues can only move rooms to Maintenance or OutOfService.");
        }

        if (Status == RoomOperationalStatus.Occupied)
        {
            throw new SharedKernel.Exceptions.DomainException("PhysicalRoom.OccupiedRoomCannotEnterMaintenance", "An occupied room cannot enter maintenance from this workflow.");
        }

        Status = blockedStatus;
    }

    public void CompleteMaintenance(bool requiresInspection)
    {
        if (Status is not (RoomOperationalStatus.Maintenance or RoomOperationalStatus.OutOfService))
        {
            throw new SharedKernel.Exceptions.DomainException("PhysicalRoom.InvalidMaintenanceReleaseStatus", "Only rooms under maintenance or out of service can be released.");
        }

        Status = requiresInspection
            ? RoomOperationalStatus.InspectionRequired
            : RoomOperationalStatus.Dirty;
    }
}
