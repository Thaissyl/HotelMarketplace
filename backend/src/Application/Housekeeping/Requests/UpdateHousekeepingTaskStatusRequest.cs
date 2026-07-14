using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.Housekeeping.Requests;

public sealed record UpdateHousekeepingTaskStatusRequest(
    HousekeepingTaskStatus Status);
