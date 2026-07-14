using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.HotelManagement.Requests;

public sealed record UpdatePhysicalRoomRequest(
    string RoomNumber,
    RoomOperationalStatus Status);
