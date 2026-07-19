using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.Availability.Dtos;

public sealed record AvailabilityCalendarDto(
    Guid HotelId,
    DateOnly StartDate,
    DateOnly EndDate,
    IReadOnlyCollection<AvailabilityRoomTypeDto> RoomTypes,
    IReadOnlyCollection<AvailabilityEntryDto> Entries,
    IReadOnlyCollection<AvailabilityCommitmentDto> ActiveCommitments);

public sealed record AvailabilityRoomTypeDto(
    Guid Id,
    string Name,
    RecordStatus Status,
    IReadOnlyCollection<AvailabilityPhysicalRoomDto> PhysicalRooms);

public sealed record AvailabilityPhysicalRoomDto(
    Guid Id,
    string RoomNumber,
    RoomOperationalStatus Status);

public sealed record AvailabilityEntryDto(
    Guid Id,
    Guid RoomTypeId,
    Guid? PhysicalRoomId,
    DateOnly StartDate,
    DateOnly EndDate,
    AvailabilityStatus Status,
    string Reason);

public sealed record AvailabilityCommitmentDto(
    Guid BookingId,
    string BookingCode,
    Guid RoomTypeId,
    DateOnly CheckInDate,
    DateOnly CheckOutDate,
    int RoomCount,
    BookingStatus Status,
    IReadOnlyCollection<Guid> AssignedPhysicalRoomIds);
