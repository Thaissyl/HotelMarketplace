using HotelMarketplace.Domain.Common;
using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Domain.Entities;

public sealed class MaintenanceRequest : Entity, IHotelScopedEntity
{
    private MaintenanceRequest()
    {
        Description = string.Empty;
    }

    public MaintenanceRequest(Guid id, Guid hotelId, Guid physicalRoomId, Guid reportedByUserAccountId, string description, MaintenanceSeverity severity, Guid? assignedToUserAccountId = null)
        : base(id)
    {
        Guard.NotEmpty(hotelId, nameof(HotelId));
        Guard.NotEmpty(physicalRoomId, nameof(PhysicalRoomId));
        Guard.NotEmpty(reportedByUserAccountId, nameof(ReportedByUserAccountId));
        HotelId = hotelId;
        PhysicalRoomId = physicalRoomId;
        ReportedByUserAccountId = reportedByUserAccountId;
        AssignedToUserAccountId = assignedToUserAccountId;
        Description = Guard.NotBlank(description, nameof(Description), 1000);
        Severity = severity;
        Status = MaintenanceStatus.Open;
        CreatedAtUtc = DateTime.UtcNow;
    }

    public Guid HotelId { get; private set; }

    public Guid PhysicalRoomId { get; private set; }

    public Guid ReportedByUserAccountId { get; private set; }

    public Guid? AssignedToUserAccountId { get; private set; }

    public string Description { get; private set; }

    public MaintenanceSeverity Severity { get; private set; }

    public MaintenanceStatus Status { get; private set; }

    public DateTime CreatedAtUtc { get; private set; }
}
