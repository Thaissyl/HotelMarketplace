using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.PlatformAdmin.Dtos;

public sealed record AdminSettlementItemDto(
    Guid Id,
    Guid? BookingId,
    Guid? CommissionRecordId,
    Guid? PaymentTransactionId,
    Guid? PaymentCollectionRecordId,
    PaymentMode PaymentMode,
    BookingStatus BookingStatus,
    decimal GrossAmount,
    decimal RefundAmount,
    decimal CommissionAmount,
    decimal Amount,
    SettlementStatus Status);
