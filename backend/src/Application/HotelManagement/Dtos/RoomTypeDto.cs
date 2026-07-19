using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.HotelManagement.Dtos;

public sealed record RoomTypeDto(
    Guid Id,
    Guid HotelId,
    string Name,
    int AdultCapacity,
    int ChildCapacity,
    decimal BasePricePerNight,
    string? Description,
    string? Facilities,
    RecordStatus Status);
