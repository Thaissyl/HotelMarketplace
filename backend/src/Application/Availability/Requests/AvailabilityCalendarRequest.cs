namespace HotelMarketplace.Application.Availability.Requests;

public sealed record AvailabilityCalendarRequest(
    DateOnly StartDate,
    DateOnly EndDate,
    Guid? RoomTypeId,
    Guid? PhysicalRoomId);
