using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.PlatformAdmin.Requests;

public sealed record CreateSettlementRequest(
    Guid HotelId,
    PaymentMode PaymentMode,
    DateOnly FromDate,
    DateOnly ToDate,
    string? AdminNote);
