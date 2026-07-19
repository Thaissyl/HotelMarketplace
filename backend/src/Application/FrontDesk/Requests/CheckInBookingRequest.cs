namespace HotelMarketplace.Application.FrontDesk.Requests;

public sealed record CheckInBookingRequest(
    IReadOnlyCollection<Guid> PhysicalRoomIds,
    string GuestFullName,
    string IdentityDocumentType,
    string IdentityDocumentNumber,
    string? IdentityIssuingCountry,
    DateOnly? IdentityExpiryDate);
