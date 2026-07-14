using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.PlatformAdmin.Dtos;

public sealed record AdminSettlementDto(
    Guid Id,
    Guid HotelId,
    string HotelName,
    string SettlementType,
    decimal TotalAmount,
    SettlementStatus Status,
    string? AdminNote,
    DateTime CreatedAtUtc,
    IReadOnlyCollection<AdminSettlementItemDto> Items);
