namespace HotelMarketplace.Application.FrontDesk.Requests;

public sealed record CreateWalkInBookingRequest(
    Guid RoomTypeId,
    IReadOnlyCollection<Guid> PhysicalRoomIds,
    DateOnly CheckInDate,
    DateOnly CheckOutDate,
    int GuestCount,
    string GuestFullName,
    string GuestPhone,
    string? IdentityDocumentNumber,
    decimal CashCollectedAmount);
