namespace HotelMarketplace.Infrastructure.Payment;

internal sealed record PayOsOptions(
    string ClientId,
    string ApiKey,
    string ChecksumKey,
    string BaseUrl,
    string ReturnUrl,
    string CancelUrl);
