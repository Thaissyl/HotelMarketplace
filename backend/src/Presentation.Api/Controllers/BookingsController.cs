using HotelMarketplace.Application.Bookings;
using HotelMarketplace.Application.Bookings.Dtos;
using HotelMarketplace.Application.Bookings.Requests;
using HotelMarketplace.Application.Payments;
using HotelMarketplace.Application.Payments.Dtos;
using HotelMarketplace.Application.Payments.Requests;
using HotelMarketplace.Domain.Enums;
using HotelMarketplace.SharedKernel.Results;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace HotelMarketplace.Presentation.Api.Controllers;

[ApiController]
[Route("api/bookings")]
[Authorize(Roles = nameof(UserRoleCode.Customer))]
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

    [HttpPost("{bookingId:guid}/demo-payment")]
    [ProducesResponseType(typeof(DemoPaymentResultDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status409Conflict)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status423Locked)]
    public async Task<IActionResult> ConfirmDemoPayment(
        Guid bookingId,
        ConfirmDemoPaymentRequest request,
        CancellationToken cancellationToken)
    {
        Result<DemoPaymentResultDto> result = await _paymentService.ConfirmDemoPaymentAsync(
            bookingId,
            request,
            cancellationToken);

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
            "Payment.AmountMismatch" => StatusCodes.Status409Conflict,
            "Payment.LockUnavailable" => StatusCodes.Status423Locked,
            _ => StatusCodes.Status400BadRequest
        };

        return this.ToProblemResult(error, statusCode);
    }
}
