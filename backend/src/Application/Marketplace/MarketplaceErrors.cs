using HotelMarketplace.SharedKernel.Results;

namespace HotelMarketplace.Application.Marketplace;

public static class MarketplaceErrors
{
    public static readonly ResultError HotelNotFound = new("Marketplace.HotelNotFound", "The hotel was not found or is not available on the marketplace.");
}
