using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.FrontDesk.Dtos;

public sealed record PaymentCollectionSummaryDto(
    Guid BookingId,
    string BookingCode,
    PaymentMode PaymentMode,
    decimal ExpectedAmount,
    decimal CollectedAmount,
    decimal RemainingBalance,
    PaymentCollectionStatus Status,
    IReadOnlyCollection<PaymentCollectionDto> Collections);

public sealed record PaymentCollectionDto(
    Guid Id,
    decimal Amount,
    decimal BalanceBefore,
    decimal BalanceAfter,
    PaymentCollectionMethod Method,
    string Reference,
    string? Note,
    PaymentCollectionStatus Status,
    DateTime CollectedAtUtc,
    DateTime? VoidedAtUtc,
    string? CorrectionNote);
