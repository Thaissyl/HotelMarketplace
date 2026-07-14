using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.PlatformAdmin.Requests;

public sealed record UpdateRefundStatusRequest(
    RefundStatus Status,
    decimal? ApprovedAmount);
