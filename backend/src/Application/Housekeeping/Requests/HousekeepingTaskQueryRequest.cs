using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.Housekeeping.Requests;

public sealed record HousekeepingTaskQueryRequest(
    HousekeepingTaskStatus? Status,
    Guid? AssignedToUserAccountId);
