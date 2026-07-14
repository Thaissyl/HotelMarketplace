using HotelMarketplace.Application.Marketplace.Dtos;
using HotelMarketplace.Application.Marketplace.Requests;

namespace HotelMarketplace.Application.Marketplace;

public interface IMarketplaceBrowsingRepository
{
    Task<IReadOnlyCollection<HotelSearchResultDto>> SearchHotelsAsync(
        HotelSearchRequest request,
        CancellationToken cancellationToken);

    Task<HotelDetailDto?> GetHotelDetailAsync(
        Guid hotelId,
        HotelDetailAvailabilityRequest request,
        CancellationToken cancellationToken);
}
