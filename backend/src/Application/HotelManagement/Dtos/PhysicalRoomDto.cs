using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.HotelManagement.Dtos;

public sealed record PhysicalRoomDto(
    Guid Id,
    Guid HotelId,
    Guid RoomTypeId,
    string RoomNumber,
    string? Floor,
    string? Notes,
    RoomOperationalStatus Status);
