namespace HotelMarketplace.Application.CustomerAccount.Requests;

public sealed record ChangeCustomerPasswordRequest(
    string CurrentPassword,
    string NewPassword,
    string ConfirmNewPassword);
