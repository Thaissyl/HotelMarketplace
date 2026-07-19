using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.Maintenance.Requests;

public sealed record UpdateMaintenanceRequestStatusRequest(
    MaintenanceStatus Status,
    string? ResolutionNote);
