namespace HotelMarketplace.Application.Maintenance.Requests;

public sealed record AssignMaintenanceRequestRequest(
    Guid AssignedToUserAccountId);
