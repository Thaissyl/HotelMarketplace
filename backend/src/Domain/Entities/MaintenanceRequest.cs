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

    public DateTime? ResolvedAtUtc { get; private set; }

    public string? ResolutionNote { get; private set; }

    public void Assign(Guid assignedToUserAccountId)
    {
        Guard.NotEmpty(assignedToUserAccountId, nameof(AssignedToUserAccountId));

        if (Status != MaintenanceStatus.Open)
        {
            throw new SharedKernel.Exceptions.DomainException("MaintenanceRequest.InvalidAssignStatus", "Only open maintenance requests can be assigned.");
        }

        AssignedToUserAccountId = assignedToUserAccountId;
    }

    public void Start(Guid assignedToUserAccountId)
    {
        Guard.NotEmpty(assignedToUserAccountId, nameof(AssignedToUserAccountId));

        if (Status != MaintenanceStatus.Open)
        {
            throw new SharedKernel.Exceptions.DomainException("MaintenanceRequest.InvalidStartStatus", "Only open maintenance requests can be started.");
        }

        AssignedToUserAccountId = assignedToUserAccountId;
        Status = MaintenanceStatus.InProgress;
    }

    public void Resolve(string resolutionNote, DateTime resolvedAtUtc)
    {
        if (Status != MaintenanceStatus.InProgress)
        {
            throw new SharedKernel.Exceptions.DomainException("MaintenanceRequest.InvalidResolveStatus", "Only in-progress maintenance requests can be resolved.");
        }

        ResolutionNote = Guard.NotBlank(resolutionNote, nameof(ResolutionNote), 1000);
        ResolvedAtUtc = resolvedAtUtc.Kind == DateTimeKind.Local
            ? throw new SharedKernel.Exceptions.DomainException("MaintenanceRequest.InvalidResolvedTime", "Resolved time must be expressed in UTC.")
            : DateTime.SpecifyKind(resolvedAtUtc, DateTimeKind.Utc);
        Status = MaintenanceStatus.Resolved;
    }

    public void Release()
    {
        if (Status != MaintenanceStatus.Resolved)
        {
            throw new SharedKernel.Exceptions.DomainException("MaintenanceRequest.InvalidReleaseStatus", "Only a resolved maintenance request can be released.");
        }

        Status = MaintenanceStatus.Released;
    }
}
