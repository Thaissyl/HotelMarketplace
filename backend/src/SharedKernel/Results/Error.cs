namespace HotelMarketplace.SharedKernel.Results;

public sealed record ResultError(string Code, string Message)
{
    public static readonly ResultError None = new(string.Empty, string.Empty);
    public static readonly ResultError NullValue = new("General.NullValue", "The specified result value is null.");
}
