using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.Bookings.Dtos;

public sealed record BookingCancellationResultDto(
    Guid BookingId,
    BookingStatus BookingStatus,
    DateTime CancelledAtUtc,
    string CancellationReason,
    decimal RefundRequestedAmount,
    Guid? RefundRecordId,
    RefundStatus? RefundStatus,
    string Summary);
