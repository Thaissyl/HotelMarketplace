namespace HotelMarketplace.SharedKernel.Exceptions;

public sealed class DomainException : HotelMarketplaceException
{
    public DomainException(string code, string message)
        : base(code, message)
    {
    }

    public DomainException(string code, string message, Exception innerException)
        : base(code, message, innerException)
    {
    }
}
