using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.Maintenance.Requests;

public sealed record MaintenanceRequestQueryRequest(
    MaintenanceStatus? Status,
    Guid? AssignedToUserAccountId);
