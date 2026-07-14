using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.FrontDesk.Dtos;

public sealed record FrontDeskBookingDto(
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
    IReadOnlyCollection<AssignedPhysicalRoomDto> AssignedRooms,
    Guid? GuestStayRecordId,
    Guid? InvoiceId);
