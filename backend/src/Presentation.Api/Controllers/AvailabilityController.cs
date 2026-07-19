using HotelMarketplace.Application.Availability;
using HotelMarketplace.Application.Availability.Dtos;
using HotelMarketplace.Application.Availability.Requests;
using HotelMarketplace.Domain.Enums;
using HotelMarketplace.Presentation.Api.Authorization;
using HotelMarketplace.SharedKernel.Results;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace HotelMarketplace.Presentation.Api.Controllers;

[ApiController]
[Route("api/hotels/{hotelId:guid}/availability")]
[Authorize(
    Policy = AuthorizationPolicies.HotelScoped,
    Roles = nameof(UserRoleCode.PropertyOwner) + "," +
        nameof(UserRoleCode.HotelManager) + "," +
        nameof(UserRoleCode.Receptionist))]
public sealed class AvailabilityController : ControllerBase
{
    private readonly IAvailabilityService _availabilityService;

    public AvailabilityController(IAvailabilityService availabilityService)
    {
        _availabilityService = availabilityService;
    }

    [HttpGet]
    [ProducesResponseType(typeof(AvailabilityCalendarDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetCalendar(
        Guid hotelId,
        [FromQuery] DateOnly startDate,
        [FromQuery] DateOnly endDate,
        [FromQuery] Guid? roomTypeId,
        [FromQuery] Guid? physicalRoomId,
        CancellationToken cancellationToken)
    {
        AvailabilityCalendarRequest request = new(startDate, endDate, roomTypeId, physicalRoomId);
        Result<AvailabilityCalendarDto> result = await _availabilityService.GetCalendarAsync(
            hotelId,
            request,
            cancellationToken);

        return result.IsFailure ? ToProblem(result.Error) : Ok(result.Value);
    }

    [HttpPost("changes")]
    [ProducesResponseType(typeof(AvailabilityCalendarDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status409Conflict)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status423Locked)]
    public async Task<IActionResult> ApplyChange(
        Guid hotelId,
        ChangeAvailabilityRequest request,
        CancellationToken cancellationToken)
    {
        Result<AvailabilityCalendarDto> result = await _availabilityService.ApplyChangeAsync(
            hotelId,
            request,
            cancellationToken);

        return result.IsFailure ? ToProblem(result.Error) : Ok(result.Value);
    }

    private ObjectResult ToProblem(ResultError error)
    {
        int statusCode = error.Code switch
        {
            "Availability.Forbidden" => StatusCodes.Status403Forbidden,
            "Availability.HotelNotFound" => StatusCodes.Status404NotFound,
            "Availability.RoomTypeNotFound" => StatusCodes.Status404NotFound,
            "Availability.PhysicalRoomNotFound" => StatusCodes.Status404NotFound,
            "Availability.ActiveBookingConflict" => StatusCodes.Status409Conflict,
            "Availability.LockUnavailable" => StatusCodes.Status423Locked,
            _ => StatusCodes.Status400BadRequest
        };

        return this.ToProblemResult(error, statusCode);
    }
}
