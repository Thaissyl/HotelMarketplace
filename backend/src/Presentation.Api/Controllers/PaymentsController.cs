using HotelMarketplace.Application.Payments;
using HotelMarketplace.Application.Payments.Dtos;
using HotelMarketplace.Application.Payments.Models;
using HotelMarketplace.SharedKernel.Results;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace HotelMarketplace.Presentation.Api.Controllers;

[ApiController]
[Route("api/payments")]
public sealed class PaymentsController : ControllerBase
{
    private readonly IPaymentService _paymentService;

    public PaymentsController(IPaymentService paymentService)
    {
        _paymentService = paymentService;
    }

    [HttpPost("payos/webhook")]
    [AllowAnonymous]
    [ProducesResponseType(typeof(PaymentWebhookResultDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status409Conflict)]
    public async Task<IActionResult> HandlePayOsWebhook(
        PaymentWebhookRequest request,
        CancellationToken cancellationToken)
    {
        Result<PaymentWebhookResultDto> result = await _paymentService.HandlePayOsWebhookAsync(request, cancellationToken);

        return result.IsFailure ? ToProblem(result.Error) : Ok(result.Value);
    }

    [HttpGet("payos/return")]
    [AllowAnonymous]
    [ProducesResponseType(StatusCodes.Status200OK)]
    public IActionResult PayOsReturn()
    {
        return Ok(new { status = "received" });
    }

    [HttpGet("payos/cancel")]
    [AllowAnonymous]
    [ProducesResponseType(StatusCodes.Status200OK)]
    public IActionResult PayOsCancel()
    {
        return Ok(new { status = "cancelled" });
    }

    private ObjectResult ToProblem(ResultError error)
    {
        int statusCode = error.Code switch
        {
            "Payment.InvalidWebhookRequest" => StatusCodes.Status400BadRequest,
            "Payment.InvalidWebhookSignature" => StatusCodes.Status400BadRequest,
            "Payment.TransactionNotFound" => StatusCodes.Status404NotFound,
            "Payment.WebhookAmountMismatch" => StatusCodes.Status409Conflict,
            "Payment.PaymentExpired" => StatusCodes.Status409Conflict,
            _ => StatusCodes.Status400BadRequest
        };

        return this.ToProblemResult(error, statusCode);
    }
}
