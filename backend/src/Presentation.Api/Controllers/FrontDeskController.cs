using HotelMarketplace.Application.FrontDesk;
using HotelMarketplace.Application.FrontDesk.Dtos;
using HotelMarketplace.Application.FrontDesk.Requests;
using HotelMarketplace.Application.HotelManagement.Dtos;
using HotelMarketplace.Domain.Enums;
using HotelMarketplace.Presentation.Api.Authorization;
using HotelMarketplace.SharedKernel.Results;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace HotelMarketplace.Presentation.Api.Controllers;

[ApiController]
[Route("api/hotels/{hotelId:guid}/front-desk")]
[Authorize(
    Policy = AuthorizationPolicies.HotelScoped,
    Roles = nameof(UserRoleCode.Receptionist) + "," +
        nameof(UserRoleCode.HotelManager) + "," +
        nameof(UserRoleCode.PropertyOwner))]
public sealed class FrontDeskController : ControllerBase
{
    private readonly IFrontDeskService _frontDeskService;

    public FrontDeskController(IFrontDeskService frontDeskService)
    {
        _frontDeskService = frontDeskService;
    }

    [HttpGet("physical-rooms")]
    [ProducesResponseType(typeof(IReadOnlyCollection<PhysicalRoomDto>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> GetPhysicalRooms(
        Guid hotelId,
        [FromQuery] Guid? roomTypeId,
        CancellationToken cancellationToken)
    {
        Result<IReadOnlyCollection<PhysicalRoomDto>> result =
            await _frontDeskService.GetPhysicalRoomsAsync(hotelId, roomTypeId, cancellationToken);

        return result.IsFailure ? ToProblem(result.Error) : Ok(result.Value);
    }

    [HttpGet("bookings")]
    [ProducesResponseType(typeof(IReadOnlyCollection<FrontDeskBookingSummaryDto>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> GetBookings(
        Guid hotelId,
        [FromQuery] BookingStatus? status,
        [FromQuery] DateOnly? fromDate,
        [FromQuery] DateOnly? toDate,
        CancellationToken cancellationToken)
    {
        Result<IReadOnlyCollection<FrontDeskBookingSummaryDto>> result =
            await _frontDeskService.GetBookingsAsync(hotelId, status, fromDate, toDate, cancellationToken);

        return result.IsFailure ? ToProblem(result.Error) : Ok(result.Value);
    }

    [HttpPost("bookings/{bookingId:guid}/check-in")]
    [ProducesResponseType(typeof(FrontDeskBookingDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status409Conflict)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status423Locked)]
    public async Task<IActionResult> CheckInBooking(
        Guid hotelId,
        Guid bookingId,
        CheckInBookingRequest request,
        CancellationToken cancellationToken)
    {
        Result<FrontDeskBookingDto> result = await _frontDeskService.CheckInBookingAsync(
            hotelId,
            bookingId,
            request,
            cancellationToken);

        return result.IsFailure ? ToProblem(result.Error) : Ok(result.Value);
    }

    [HttpPost("bookings/{bookingId:guid}/check-out")]
    [ProducesResponseType(typeof(FrontDeskBookingDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status409Conflict)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status423Locked)]
    public async Task<IActionResult> CheckOutBooking(
        Guid hotelId,
        Guid bookingId,
        CheckOutBookingRequest request,
        CancellationToken cancellationToken)
    {
        Result<FrontDeskBookingDto> result = await _frontDeskService.CheckOutBookingAsync(
            hotelId,
            bookingId,
            request,
            cancellationToken);

        return result.IsFailure ? ToProblem(result.Error) : Ok(result.Value);
    }

    [HttpGet("bookings/{bookingId:guid}/payment-collections")]
    [ProducesResponseType(typeof(PaymentCollectionSummaryDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status409Conflict)]
    public async Task<IActionResult> GetPaymentCollections(
        Guid hotelId,
        Guid bookingId,
        CancellationToken cancellationToken)
    {
        Result<PaymentCollectionSummaryDto> result = await _frontDeskService.GetPaymentCollectionSummaryAsync(
            hotelId,
            bookingId,
            cancellationToken);

        return result.IsFailure ? ToProblem(result.Error) : Ok(result.Value);
    }

    [HttpPost("bookings/{bookingId:guid}/payment-collections")]
    [ProducesResponseType(typeof(PaymentCollectionSummaryDto), StatusCodes.Status201Created)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status409Conflict)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status423Locked)]
    public async Task<IActionResult> RecordPaymentCollection(
        Guid hotelId,
        Guid bookingId,
        RecordPaymentCollectionRequest request,
        CancellationToken cancellationToken)
    {
        Result<PaymentCollectionSummaryDto> result = await _frontDeskService.RecordPaymentCollectionAsync(
            hotelId,
            bookingId,
            request,
            cancellationToken);

        return result.IsFailure
            ? ToProblem(result.Error)
            : CreatedAtAction(nameof(GetPaymentCollections), new { hotelId, bookingId }, result.Value);
    }

    [HttpPost("bookings/{bookingId:guid}/no-show")]
    [ProducesResponseType(typeof(FrontDeskBookingDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status409Conflict)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status423Locked)]
    public async Task<IActionResult> MarkBookingNoShow(
        Guid hotelId,
        Guid bookingId,
        MarkBookingNoShowRequest request,
        CancellationToken cancellationToken)
    {
        Result<FrontDeskBookingDto> result = await _frontDeskService.MarkBookingNoShowAsync(
            hotelId,
            bookingId,
            request,
            cancellationToken);

        return result.IsFailure ? ToProblem(result.Error) : Ok(result.Value);
    }

    [HttpPost("walk-in-bookings")]
    [ProducesResponseType(typeof(FrontDeskBookingDto), StatusCodes.Status201Created)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status409Conflict)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status423Locked)]
    public async Task<IActionResult> CreateWalkInBooking(
        Guid hotelId,
        CreateWalkInBookingRequest request,
        CancellationToken cancellationToken)
    {
        Result<FrontDeskBookingDto> result = await _frontDeskService.CreateWalkInBookingAsync(
            hotelId,
            request,
            cancellationToken);

        return result.IsFailure
            ? ToProblem(result.Error)
            : CreatedAtAction(nameof(CreateWalkInBooking), new { hotelId, bookingId = result.Value.BookingId }, result.Value);
    }

    private ObjectResult ToProblem(ResultError error)
    {
        int statusCode = error.Code switch
        {
            "FrontDesk.Forbidden" => StatusCodes.Status403Forbidden,
            "FrontDesk.BookingNotFound" => StatusCodes.Status404NotFound,
            "FrontDesk.RoomTypeNotAvailable" => StatusCodes.Status404NotFound,
            "FrontDesk.InvalidBookingStatusForCheckIn" => StatusCodes.Status409Conflict,
            "FrontDesk.InvalidBookingStatusForCheckOut" => StatusCodes.Status409Conflict,
            "FrontDesk.InvalidRoomAssignment" => StatusCodes.Status409Conflict,
            "FrontDesk.RoomAssignmentOverlap" => StatusCodes.Status409Conflict,
            "FrontDesk.PaymentCollectionRequired" => StatusCodes.Status409Conflict,
            "FrontDesk.CapacityExceeded" => StatusCodes.Status400BadRequest,
            "FrontDesk.InsufficientAvailability" => StatusCodes.Status409Conflict,
            "FrontDesk.IncorrectCashAmount" => StatusCodes.Status400BadRequest,
            "FrontDesk.InvalidPaymentCollectionRequest" => StatusCodes.Status400BadRequest,
            "FrontDesk.InvalidCollectionAmount" => StatusCodes.Status400BadRequest,
            "FrontDesk.WrongPaymentMode" => StatusCodes.Status409Conflict,
            "FrontDesk.DuplicateCollectionReference" => StatusCodes.Status409Conflict,
            "FrontDesk.LockUnavailable" => StatusCodes.Status423Locked,
            "FrontDesk.InvalidNoShowRequest" => StatusCodes.Status400BadRequest,
            "FrontDesk.InvalidBookingStatusForNoShow" => StatusCodes.Status409Conflict,
            "FrontDesk.NoShowWindowNotReached" => StatusCodes.Status409Conflict,
            _ => StatusCodes.Status400BadRequest
        };

        return this.ToProblemResult(error, statusCode);
    }
}
