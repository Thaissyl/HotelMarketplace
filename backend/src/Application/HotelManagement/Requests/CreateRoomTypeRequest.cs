namespace HotelMarketplace.Application.HotelManagement.Requests;

public sealed record CreateRoomTypeRequest(
    string Name,
    int AdultCapacity,
    int ChildCapacity,
    decimal BasePricePerNight,
    string? Description,
    string? Facilities = null);
