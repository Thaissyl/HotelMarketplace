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
        Status = initialStatus is RoomOperationalStatus.Available or RoomOperationalStatus.Dirty or RoomOperationalStatus.Maintenance or RoomOperationalStatus.OutOfService
            ? initialStatus
            : throw new SharedKernel.Exceptions.DomainException("PhysicalRoom.InvalidInitialStatus", "Initial room status must be Available, Dirty, Maintenance, or OutOfService.");
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
        if (status is not (RoomOperationalStatus.Available or RoomOperationalStatus.Dirty or RoomOperationalStatus.Maintenance or RoomOperationalStatus.OutOfService or RoomOperationalStatus.Inactive))
        {
            throw new SharedKernel.Exceptions.DomainException("PhysicalRoom.InvalidSetupStatus", "Setup status must be Available, Dirty, Maintenance, OutOfService, or Inactive.");
        }

        if (Status == RoomOperationalStatus.Occupied && status == RoomOperationalStatus.Inactive)
        {
            throw new SharedKernel.Exceptions.DomainException("PhysicalRoom.OccupiedRoomCannotBeInactive", "An occupied room cannot be inactivated.");
        }

        Status = status;
    }
}
