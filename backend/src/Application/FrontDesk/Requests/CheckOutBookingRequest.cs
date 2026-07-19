using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.FrontDesk.Requests;

public sealed record CheckOutBookingRequest(
    bool ConfirmPayAtPropertyCollection,
    decimal CashCollectedAmount,
    PaymentCollectionMethod CollectionMethod = PaymentCollectionMethod.Cash,
    string? CollectionReference = null,
    string? CollectionNote = null);
