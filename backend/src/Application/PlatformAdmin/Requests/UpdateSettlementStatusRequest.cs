using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.PlatformAdmin.Requests;

public sealed record UpdateSettlementStatusRequest(
    SettlementStatus Status,
    decimal? SettledAmount,
    DateTime? SettlementDateUtc,
    string? Reference,
    string? AdminNote);
