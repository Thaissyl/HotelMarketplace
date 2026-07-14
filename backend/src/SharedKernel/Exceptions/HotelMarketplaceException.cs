namespace HotelMarketplace.SharedKernel.Exceptions;

public abstract class HotelMarketplaceException : Exception
{
    protected HotelMarketplaceException(string code, string message)
        : base(message)
    {
        Code = code;
    }

    protected HotelMarketplaceException(string code, string message, Exception innerException)
        : base(message, innerException)
    {
        Code = code;
    }

    public string Code { get; }
}
