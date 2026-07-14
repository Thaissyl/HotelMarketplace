using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.PlatformAdmin.Requests;

public sealed record UpdatePaymentReconciliationRequest(
    ReconciliationStatus Status);
