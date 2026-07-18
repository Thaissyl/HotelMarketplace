namespace HotelMarketplace.Application.CustomerAccount.Requests;

public sealed record UpdateCustomerProfileRequest(
    string FullName,
    string? PhoneNumber);
