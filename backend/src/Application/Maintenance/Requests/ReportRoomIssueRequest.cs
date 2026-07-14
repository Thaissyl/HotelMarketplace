using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.Maintenance.Requests;

public sealed record ReportRoomIssueRequest(
    Guid PhysicalRoomId,
    string Description,
    MaintenanceSeverity Severity,
    RoomOperationalStatus TargetRoomStatus);
