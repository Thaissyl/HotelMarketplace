using HotelMarketplace.Application.Marketplace;
using HotelMarketplace.Application.Marketplace.Dtos;
using HotelMarketplace.Application.Marketplace.Requests;
using HotelMarketplace.SharedKernel.Results;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace HotelMarketplace.Presentation.Api.Controllers;

[ApiController]
[Route("api/public/hotels")]
[AllowAnonymous]
public sealed class PublicHotelsController : ControllerBase
{
    private readonly IMarketplaceBrowsingService _marketplaceBrowsingService;

    public PublicHotelsController(IMarketplaceBrowsingService marketplaceBrowsingService)
    {
        _marketplaceBrowsingService = marketplaceBrowsingService;
    }

    [HttpGet]
    [ProducesResponseType(typeof(IReadOnlyCollection<HotelSearchResultDto>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> SearchHotels(
        [FromQuery] string? location,
        [FromQuery] DateOnly checkInDate,
        [FromQuery] DateOnly checkOutDate,
        [FromQuery] int guestCount = 1,
        [FromQuery] int roomCount = 1,
        CancellationToken cancellationToken = default)
    {
        HotelSearchRequest request = new(location, checkInDate, checkOutDate, guestCount, roomCount);
        Result<IReadOnlyCollection<HotelSearchResultDto>> result = await _marketplaceBrowsingService.SearchHotelsAsync(request, cancellationToken);

        return result.IsFailure ? ToProblem(result.Error) : Ok(result.Value);
    }

    [HttpGet("{hotelId:guid}")]
    [ProducesResponseType(typeof(HotelDetailDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetHotelDetail(
        Guid hotelId,
        [FromQuery] DateOnly checkInDate,
        [FromQuery] DateOnly checkOutDate,
        [FromQuery] int guestCount = 1,
        [FromQuery] int roomCount = 1,
        CancellationToken cancellationToken = default)
    {
        HotelDetailAvailabilityRequest request = new(checkInDate, checkOutDate, guestCount, roomCount);
        Result<HotelDetailDto> result = await _marketplaceBrowsingService.GetHotelDetailAsync(hotelId, request, cancellationToken);

        return result.IsFailure ? ToProblem(result.Error) : Ok(result.Value);
    }

    private ObjectResult ToProblem(ResultError error)
    {
        int statusCode = error.Code switch
        {
            "Marketplace.HotelNotFound" => StatusCodes.Status404NotFound,
            _ => StatusCodes.Status400BadRequest
        };

        return this.ToProblemResult(error, statusCode);
    }
}
