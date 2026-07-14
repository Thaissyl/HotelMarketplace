using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.Maintenance.Dtos;

public sealed record MaintenanceRequestDto(
    Guid Id,
    Guid HotelId,
    Guid PhysicalRoomId,
    string RoomNumber,
    Guid ReportedByUserAccountId,
    Guid? AssignedToUserAccountId,
    string Description,
    MaintenanceSeverity Severity,
    MaintenanceStatus Status,
    RoomOperationalStatus RoomStatus,
    DateTime CreatedAtUtc);
