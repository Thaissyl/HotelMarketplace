using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.HotelManagement.Requests;

public sealed record CreatePhysicalRoomRequest(
    Guid RoomTypeId,
    string RoomNumber,
    RoomOperationalStatus InitialStatus,
    string? Floor = null,
    string? Notes = null);
