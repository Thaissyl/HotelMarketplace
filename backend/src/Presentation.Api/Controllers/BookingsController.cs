using HotelMarketplace.Application.Bookings;
using HotelMarketplace.Application.Bookings.Dtos;
using HotelMarketplace.Application.Bookings.Requests;
using HotelMarketplace.Application.Payments;
using HotelMarketplace.Application.Payments.Dtos;
using HotelMarketplace.Domain.Enums;
using HotelMarketplace.SharedKernel.Results;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace HotelMarketplace.Presentation.Api.Controllers;

[ApiController]
[Route("api/bookings")]
[Authorize(Roles = nameof(UserRoleCode.Customer) + "," + nameof(UserRoleCode.PlatformAdministrator))]
public sealed class BookingsController : ControllerBase
{
    private readonly IBookingService _bookingService;
    private readonly IPaymentService _paymentService;

    public BookingsController(
        IBookingService bookingService,
        IPaymentService paymentService)
    {
        _bookingService = bookingService;
        _paymentService = paymentService;
    }

    [HttpGet("my")]
    [ProducesResponseType(typeof(IReadOnlyCollection<BookingDto>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> GetMyBookings(CancellationToken cancellationToken)
    {
        Result<IReadOnlyCollection<BookingDto>> result = await _bookingService.GetMyBookingsAsync(cancellationToken);

        return result.IsFailure ? ToProblem(result.Error) : Ok(result.Value);
    }

    [HttpPost]
    [ProducesResponseType(typeof(BookingDto), StatusCodes.Status201Created)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status409Conflict)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status423Locked)]
    public async Task<IActionResult> CreateBooking(
        CreateBookingRequest request,
        CancellationToken cancellationToken)
    {
        Result<BookingDto> result = await _bookingService.CreateBookingAsync(request, cancellationToken);

        if (result.IsFailure)
        {
            return ToProblem(result.Error);
        }

        return CreatedAtAction(nameof(CreateBooking), new { bookingId = result.Value.Id }, result.Value);
    }

    [HttpPost("{bookingId:guid}/payment-link")]
    [ProducesResponseType(typeof(PaymentLinkDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status409Conflict)]
    public async Task<IActionResult> CreatePaymentLink(
        Guid bookingId,
        CancellationToken cancellationToken)
    {
        Result<PaymentLinkDto> result = await _paymentService.CreatePaymentLinkAsync(bookingId, cancellationToken);

        return result.IsFailure ? ToProblem(result.Error) : Ok(result.Value);
    }

    [HttpPost("{bookingId:guid}/simulate-payment-success")]
    [ProducesResponseType(typeof(PaymentWebhookResultDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status409Conflict)]
    public async Task<IActionResult> SimulatePaymentSuccess(
        Guid bookingId,
        CancellationToken cancellationToken)
    {
        Result<PaymentWebhookResultDto> result = await _paymentService.SimulateSuccessfulPaymentAsync(bookingId, cancellationToken);

        return result.IsFailure ? ToProblem(result.Error) : Ok(result.Value);
    }

    private ObjectResult ToProblem(ResultError error)
    {
        int statusCode = error.Code switch
        {
            "Booking.Forbidden" => StatusCodes.Status403Forbidden,
            "Booking.HotelNotAvailable" => StatusCodes.Status404NotFound,
            "Booking.RoomTypeNotAvailable" => StatusCodes.Status404NotFound,
            "Booking.CapacityExceeded" => StatusCodes.Status400BadRequest,
            "Booking.InsufficientAvailability" => StatusCodes.Status409Conflict,
            "Booking.ReservationLockUnavailable" => StatusCodes.Status423Locked,
            "Payment.Forbidden" => StatusCodes.Status403Forbidden,
            "Payment.BookingNotFound" => StatusCodes.Status404NotFound,
            "Payment.BookingNotPendingPayment" => StatusCodes.Status409Conflict,
            "Payment.PaymentExpired" => StatusCodes.Status409Conflict,
            "Payment.InvalidAmount" => StatusCodes.Status400BadRequest,
            "Payment.GatewayRejected" => StatusCodes.Status502BadGateway,
            _ => StatusCodes.Status400BadRequest
        };

        return this.ToProblemResult(error, statusCode);
    }
}
