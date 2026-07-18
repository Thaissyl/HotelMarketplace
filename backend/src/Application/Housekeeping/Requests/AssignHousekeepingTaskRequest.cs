namespace HotelMarketplace.Application.Housekeeping.Requests;

public sealed record AssignHousekeepingTaskRequest(
    Guid AssignedToUserAccountId);
