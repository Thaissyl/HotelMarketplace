using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.FrontDesk.Dtos;

public sealed record FrontDeskBookingSummaryDto(
    Guid BookingId,
    string BookingCode,
    Guid HotelId,
    BookingStatus Status,
    PaymentMode PaymentMode,
    BookingSource Source,
    DateOnly CheckInDate,
    DateOnly CheckOutDate,
    decimal TotalAmount,
    string GuestFullName,
    string GuestPhone,
    Guid RoomTypeId,
    string RoomTypeName,
    int RoomQuantity,
    int Nights,
    IReadOnlyCollection<AssignedPhysicalRoomDto> AssignedRooms,
    Guid? GuestStayRecordId,
    Guid? InvoiceId,
    DateTime CreatedAtUtc);
