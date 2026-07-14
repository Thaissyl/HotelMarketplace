using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.PlatformAdmin.Dtos;

public sealed record AdminSettlementItemDto(
    Guid Id,
    Guid? BookingId,
    Guid? CommissionRecordId,
    Guid? PaymentTransactionId,
    decimal Amount,
    SettlementStatus Status);
