using HotelMarketplace.SharedKernel.Results;

namespace HotelMarketplace.Application.CustomerAccount;

public static class CustomerAccountErrors
{
    public static readonly ResultError Forbidden = new(
        "CustomerAccount.Forbidden",
        "The current user is not allowed to manage this customer account.");

    public static readonly ResultError UserNotFound = new(
        "CustomerAccount.UserNotFound",
        "The current user account could not be found.");

    public static readonly ResultError InvalidCurrentPassword = new(
        "CustomerAccount.InvalidCurrentPassword",
        "The current password is incorrect.");

    public static readonly ResultError DuplicatePhoneNumber = new(
        "CustomerAccount.DuplicatePhoneNumber",
        "This phone number is already used by another account.");
}
