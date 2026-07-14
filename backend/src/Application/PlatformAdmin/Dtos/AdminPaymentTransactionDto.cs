using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.PlatformAdmin.Dtos;

public sealed record AdminPaymentTransactionDto(
    Guid Id,
    Guid HotelId,
    string HotelName,
    Guid BookingId,
    string Provider,
    string? GatewayReference,
    string? GatewayTransactionReference,
    decimal Amount,
    PaymentStatus Status,
    ReconciliationStatus ReconciliationStatus,
    DateTime CreatedAtUtc,
    DateTime? PaidAtUtc);
