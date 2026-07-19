using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.FrontDesk.Requests;

public sealed record RecordPaymentCollectionRequest(
    decimal Amount,
    PaymentCollectionMethod Method,
    DateTime CollectedAtUtc,
    string Reference,
    string? Note);
