using HotelMarketplace.SharedKernel.Results;

namespace HotelMarketplace.Application.Authentication;

public static class AuthenticationErrors
{
    public static readonly ResultError DuplicateEmail = new("Auth.DuplicateEmail", "An account with this email already exists.");
    public static readonly ResultError InvalidCredentials = new("Auth.InvalidCredentials", "Email or password is incorrect.");
    public static readonly ResultError InvalidRegistrationRole = new("Auth.InvalidRegistrationRole", "Only Customer and PropertyOwner registration is allowed through the public register endpoint.");
    public static readonly ResultError InactiveAccount = new("Auth.InactiveAccount", "This account is not active.");
}
