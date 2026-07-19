using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.PlatformAdmin.Dtos;

public sealed record AdminSettlementDto(
    Guid Id,
    Guid HotelId,
    string HotelName,
    SettlementType SettlementType,
    decimal ExpectedAmount,
    decimal? SettledAmount,
    SettlementStatus Status,
    string? AdminNote,
    DateTime CreatedAtUtc,
    DateTime? SettlementDateUtc,
    string Reference,
    IReadOnlyCollection<AdminSettlementItemDto> Items);
