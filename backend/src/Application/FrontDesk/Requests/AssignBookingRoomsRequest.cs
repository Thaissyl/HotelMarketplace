namespace HotelMarketplace.Application.FrontDesk.Requests;

public sealed record AssignBookingRoomsRequest(
    IReadOnlyCollection<Guid> PhysicalRoomIds);
