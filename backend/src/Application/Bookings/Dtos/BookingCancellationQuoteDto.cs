using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.Bookings.Dtos;

public sealed record BookingCancellationQuoteDto(
    Guid BookingId,
    BookingStatus BookingStatus,
    PaymentMode PaymentMode,
    bool CanCancel,
    bool IsPaid,
    string? PolicyName,
    int? FreeCancellationHours,
    decimal RefundPercentage,
    DateTime? FreeCancellationDeadlineUtc,
    bool IsWithinFreeCancellationWindow,
    decimal EstimatedRefundAmount,
    string Summary);
