using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.FrontDesk.Dtos;

public sealed record AssignedPhysicalRoomDto(
    Guid PhysicalRoomId,
    string RoomNumber,
    Guid RoomTypeId,
    RoomOperationalStatus Status);
