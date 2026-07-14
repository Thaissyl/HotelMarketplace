namespace HotelMarketplace.Application.PlatformAdmin.Dtos;

public sealed record AdminFinanceSummaryDto(
    Guid HotelId,
    string HotelName,
    decimal GrossBookingRevenue,
    decimal PlatformCommission,
    decimal HotelNetReceivable,
    int SuccessfulBookingCount);
