using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.PlatformAdmin.Requests;

public sealed record UpdateSettlementStatusRequest(
    SettlementStatus Status,
    string? AdminNote);
