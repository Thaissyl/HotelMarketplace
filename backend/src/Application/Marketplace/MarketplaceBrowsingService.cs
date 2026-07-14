using FluentValidation;
using FluentValidation.Results;
using HotelMarketplace.Application.Common.Validation;
using HotelMarketplace.Application.Marketplace.Dtos;
using HotelMarketplace.Application.Marketplace.Requests;
using HotelMarketplace.SharedKernel.Results;

namespace HotelMarketplace.Application.Marketplace;

internal sealed class MarketplaceBrowsingService : IMarketplaceBrowsingService
{
    private readonly IMarketplaceBrowsingRepository _repository;
    private readonly IValidator<HotelSearchRequest> _hotelSearchValidator;
    private readonly IValidator<HotelDetailAvailabilityRequest> _hotelDetailAvailabilityValidator;

    public MarketplaceBrowsingService(
        IMarketplaceBrowsingRepository repository,
        IValidator<HotelSearchRequest> hotelSearchValidator,
        IValidator<HotelDetailAvailabilityRequest> hotelDetailAvailabilityValidator)
    {
        _repository = repository;
        _hotelSearchValidator = hotelSearchValidator;
        _hotelDetailAvailabilityValidator = hotelDetailAvailabilityValidator;
    }

    public async Task<Result<IReadOnlyCollection<HotelSearchResultDto>>> SearchHotelsAsync(
        HotelSearchRequest request,
        CancellationToken cancellationToken)
    {
        ValidationResult validationResult = await _hotelSearchValidator.ValidateAsync(request, cancellationToken);
        if (!validationResult.IsValid)
        {
            return Result.Failure<IReadOnlyCollection<HotelSearchResultDto>>(
                ValidationErrorFormatter.ToResultError("Marketplace.InvalidSearchCriteria", validationResult));
        }

        IReadOnlyCollection<HotelSearchResultDto> hotels = await _repository.SearchHotelsAsync(request, cancellationToken);

        return Result.Success(hotels);
    }

    public async Task<Result<HotelDetailDto>> GetHotelDetailAsync(
        Guid hotelId,
        HotelDetailAvailabilityRequest request,
        CancellationToken cancellationToken)
    {
        ValidationResult validationResult = await _hotelDetailAvailabilityValidator.ValidateAsync(request, cancellationToken);
        if (!validationResult.IsValid)
        {
            return Result.Failure<HotelDetailDto>(
                ValidationErrorFormatter.ToResultError("Marketplace.InvalidAvailabilityCriteria", validationResult));
        }

        HotelDetailDto? hotel = await _repository.GetHotelDetailAsync(hotelId, request, cancellationToken);

        return hotel is null
            ? Result.Failure<HotelDetailDto>(MarketplaceErrors.HotelNotFound)
            : Result.Success(hotel);
    }
}
