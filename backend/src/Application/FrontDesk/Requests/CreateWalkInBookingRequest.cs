namespace HotelMarketplace.Application.FrontDesk.Requests;

public sealed record CreateWalkInBookingRequest(
    Guid RoomTypeId,
    int RoomCount,
    IReadOnlyCollection<Guid>? PhysicalRoomIds,
    DateOnly CheckInDate,
    DateOnly CheckOutDate,
    int GuestCount,
    string GuestFullName,
    string GuestPhone,
    string? IdentityDocumentType,
    string? IdentityDocumentNumber,
    string? IdentityIssuingCountry,
    DateOnly? IdentityExpiryDate,
    decimal CashCollectedAmount);
