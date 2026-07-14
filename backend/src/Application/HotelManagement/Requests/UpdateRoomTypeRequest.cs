namespace HotelMarketplace.Application.HotelManagement.Requests;

public sealed record UpdateRoomTypeRequest(
    string Name,
    int AdultCapacity,
    int ChildCapacity,
    decimal BasePricePerNight,
    string? Description);
