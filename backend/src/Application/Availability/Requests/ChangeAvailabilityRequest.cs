using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.Availability.Requests;

public sealed record ChangeAvailabilityRequest(
    Guid RoomTypeId,
    Guid? PhysicalRoomId,
    DateOnly StartDate,
    DateOnly EndDate,
    AvailabilityChangeAction Action,
    string? Reason);
