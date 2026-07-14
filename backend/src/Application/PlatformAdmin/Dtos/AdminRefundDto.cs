using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.PlatformAdmin.Dtos;

public sealed record AdminRefundDto(
    Guid Id,
    Guid HotelId,
    string HotelName,
    Guid BookingId,
    decimal RequestedAmount,
    decimal ApprovedAmount,
    string Reason,
    RefundStatus Status,
    DateTime CreatedAtUtc);
