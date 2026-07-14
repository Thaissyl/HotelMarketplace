using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.Housekeeping.Dtos;

public sealed record HousekeepingTaskDto(
    Guid Id,
    Guid HotelId,
    Guid PhysicalRoomId,
    string RoomNumber,
    Guid? BookingId,
    Guid? AssignedToUserAccountId,
    string TaskType,
    HousekeepingTaskStatus Status,
    RoomOperationalStatus RoomStatus,
    DateTime CreatedAtUtc);
