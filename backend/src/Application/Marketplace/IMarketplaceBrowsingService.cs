using HotelMarketplace.Application.Marketplace.Dtos;
using HotelMarketplace.Application.Marketplace.Requests;
using HotelMarketplace.SharedKernel.Results;

namespace HotelMarketplace.Application.Marketplace;

public interface IMarketplaceBrowsingService
{
    Task<Result<IReadOnlyCollection<HotelSearchResultDto>>> SearchHotelsAsync(
        HotelSearchRequest request,
        CancellationToken cancellationToken);

    Task<Result<HotelDetailDto>> GetHotelDetailAsync(
        Guid hotelId,
        HotelDetailAvailabilityRequest request,
        CancellationToken cancellationToken);
}
