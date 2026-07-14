namespace HotelMarketplace.Application.FrontDesk.Requests;

public sealed record CheckOutBookingRequest(
    bool ConfirmPayAtPropertyCollection,
    decimal CashCollectedAmount);
