using HotelMarketplace.Application.PlatformAdmin;
using HotelMarketplace.Application.PlatformAdmin.Dtos;
using HotelMarketplace.Application.PlatformAdmin.Requests;
using HotelMarketplace.Domain.Enums;
using HotelMarketplace.SharedKernel.Results;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace HotelMarketplace.Presentation.Api.Controllers;

[ApiController]
[Route("api/platform-admin")]
[Authorize(Roles = nameof(UserRoleCode.PlatformAdministrator))]
public sealed class PlatformAdminController : ControllerBase
{
    private readonly IPlatformAdminService _platformAdminService;

    public PlatformAdminController(IPlatformAdminService platformAdminService)
    {
        _platformAdminService = platformAdminService;
    }

    [HttpGet("users")]
    [ProducesResponseType(typeof(IReadOnlyCollection<AdminUserDto>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> GetUsers(
        [FromQuery] UserRoleCode? role,
        [FromQuery] string? searchTerm,
        CancellationToken cancellationToken)
    {
        Result<IReadOnlyCollection<AdminUserDto>> result = await _platformAdminService.GetUsersAsync(
            role,
            searchTerm,
            cancellationToken);

        return result.IsFailure ? ToProblem(result.Error) : Ok(result.Value);
    }

    [HttpPost("users/{userId:guid}/suspend")]
    [ProducesResponseType(typeof(AdminUserDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status409Conflict)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status423Locked)]
    public async Task<IActionResult> SuspendUser(Guid userId, CancellationToken cancellationToken)
    {
        Result<AdminUserDto> result = await _platformAdminService.SuspendUserAsync(userId, cancellationToken);
        return result.IsFailure ? ToProblem(result.Error) : Ok(result.Value);
    }

    [HttpPost("users/{userId:guid}/reactivate")]
    [ProducesResponseType(typeof(AdminUserDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status409Conflict)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status423Locked)]
    public async Task<IActionResult> ReactivateUser(Guid userId, CancellationToken cancellationToken)
    {
        Result<AdminUserDto> result = await _platformAdminService.ReactivateUserAsync(userId, cancellationToken);
        return result.IsFailure ? ToProblem(result.Error) : Ok(result.Value);
    }

    [HttpGet("users/{userId:guid}/activity")]
    [ProducesResponseType(typeof(IReadOnlyCollection<AdminUserActivityDto>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> GetUserActivity(Guid userId, CancellationToken cancellationToken)
    {
        Result<IReadOnlyCollection<AdminUserActivityDto>> result = await _platformAdminService.GetUserActivityAsync(userId, cancellationToken);
        return result.IsFailure ? ToProblem(result.Error) : Ok(result.Value);
    }

    [HttpGet("hotels/pending-review")]
    [ProducesResponseType(typeof(IReadOnlyCollection<AdminHotelDto>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> GetPendingHotels(CancellationToken cancellationToken)
    {
        Result<IReadOnlyCollection<AdminHotelDto>> result = await _platformAdminService.GetPendingHotelsAsync(cancellationToken);
        return result.IsFailure ? ToProblem(result.Error) : Ok(result.Value);
    }

    [HttpGet("hotels")]
    [ProducesResponseType(typeof(IReadOnlyCollection<AdminHotelDto>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> GetHotels(CancellationToken cancellationToken)
    {
        Result<IReadOnlyCollection<AdminHotelDto>> result =
            await _platformAdminService.GetHotelsAsync(cancellationToken);
        return result.IsFailure ? ToProblem(result.Error) : Ok(result.Value);
    }

    [HttpPost("hotels/{hotelId:guid}/approve")]
    [ProducesResponseType(typeof(AdminHotelDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status409Conflict)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status423Locked)]
    public async Task<IActionResult> ApproveHotel(Guid hotelId, CancellationToken cancellationToken)
    {
        Result<AdminHotelDto> result = await _platformAdminService.ApproveHotelAsync(hotelId, cancellationToken);
        return result.IsFailure ? ToProblem(result.Error) : Ok(result.Value);
    }

    [HttpPost("hotels/{hotelId:guid}/reject")]
    [ProducesResponseType(typeof(AdminHotelDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status409Conflict)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status423Locked)]
    public async Task<IActionResult> RejectHotel(
        Guid hotelId,
        RejectHotelRequest request,
        CancellationToken cancellationToken)
    {
        Result<AdminHotelDto> result = await _platformAdminService.RejectHotelAsync(hotelId, request, cancellationToken);
        return result.IsFailure ? ToProblem(result.Error) : Ok(result.Value);
    }

    [HttpPut("hotels/{hotelId:guid}/commission-rate")]
    [ProducesResponseType(typeof(AdminHotelDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status423Locked)]
    public async Task<IActionResult> UpdateCommissionRate(
        Guid hotelId,
        UpdateCommissionRateRequest request,
        CancellationToken cancellationToken)
    {
        Result<AdminHotelDto> result = await _platformAdminService.UpdateCommissionRateAsync(hotelId, request, cancellationToken);
        return result.IsFailure ? ToProblem(result.Error) : Ok(result.Value);
    }

    [HttpGet("finance/summary")]
    [ProducesResponseType(typeof(IReadOnlyCollection<AdminFinanceSummaryDto>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> GetFinanceSummary(
        [FromQuery] Guid? hotelId,
        [FromQuery] DateOnly? fromDate,
        [FromQuery] DateOnly? toDate,
        CancellationToken cancellationToken)
    {
        Result<IReadOnlyCollection<AdminFinanceSummaryDto>> result = await _platformAdminService.GetFinanceSummaryAsync(
            hotelId,
            fromDate,
            toDate,
            cancellationToken);

        return result.IsFailure ? ToProblem(result.Error) : Ok(result.Value);
    }

    [HttpGet("payments")]
    [ProducesResponseType(typeof(IReadOnlyCollection<AdminPaymentTransactionDto>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> GetPaymentTransactions(
        [FromQuery] ReconciliationStatus? reconciliationStatus,
        CancellationToken cancellationToken)
    {
        Result<IReadOnlyCollection<AdminPaymentTransactionDto>> result = await _platformAdminService.GetPaymentTransactionsAsync(
            reconciliationStatus,
            cancellationToken);

        return result.IsFailure ? ToProblem(result.Error) : Ok(result.Value);
    }

    [HttpPatch("payments/{paymentTransactionId:guid}/reconciliation")]
    [ProducesResponseType(typeof(AdminPaymentTransactionDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status409Conflict)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status423Locked)]
    public async Task<IActionResult> UpdatePaymentReconciliation(
        Guid paymentTransactionId,
        UpdatePaymentReconciliationRequest request,
        CancellationToken cancellationToken)
    {
        Result<AdminPaymentTransactionDto> result = await _platformAdminService.UpdatePaymentReconciliationAsync(
            paymentTransactionId,
            request,
            cancellationToken);

        return result.IsFailure ? ToProblem(result.Error) : Ok(result.Value);
    }

    [HttpGet("settlements")]
    [ProducesResponseType(typeof(IReadOnlyCollection<AdminSettlementDto>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> GetSettlements(
        [FromQuery] Guid? hotelId,
        [FromQuery] SettlementStatus? status,
        CancellationToken cancellationToken)
    {
        Result<IReadOnlyCollection<AdminSettlementDto>> result = await _platformAdminService.GetSettlementsAsync(
            hotelId,
            status,
            cancellationToken);

        return result.IsFailure ? ToProblem(result.Error) : Ok(result.Value);
    }

    [HttpPost("settlements")]
    [ProducesResponseType(typeof(AdminSettlementDto), StatusCodes.Status201Created)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status409Conflict)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status423Locked)]
    public async Task<IActionResult> CreateSettlement(
        CreateSettlementRequest request,
        CancellationToken cancellationToken)
    {
        Result<AdminSettlementDto> result = await _platformAdminService.CreateSettlementAsync(request, cancellationToken);
        return result.IsFailure
            ? ToProblem(result.Error)
            : CreatedAtAction(nameof(GetSettlements), new { settlementId = result.Value.Id }, result.Value);
    }

    [HttpPatch("settlements/{settlementId:guid}/status")]
    [ProducesResponseType(typeof(AdminSettlementDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status409Conflict)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status423Locked)]
    public async Task<IActionResult> UpdateSettlementStatus(
        Guid settlementId,
        UpdateSettlementStatusRequest request,
        CancellationToken cancellationToken)
    {
        Result<AdminSettlementDto> result = await _platformAdminService.UpdateSettlementStatusAsync(
            settlementId,
            request,
            cancellationToken);

        return result.IsFailure ? ToProblem(result.Error) : Ok(result.Value);
    }

    [HttpGet("refunds")]
    [ProducesResponseType(typeof(IReadOnlyCollection<AdminRefundDto>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> GetRefunds(
        [FromQuery] RefundStatus? status,
        CancellationToken cancellationToken)
    {
        Result<IReadOnlyCollection<AdminRefundDto>> result = await _platformAdminService.GetRefundsAsync(status, cancellationToken);
        return result.IsFailure ? ToProblem(result.Error) : Ok(result.Value);
    }

    [HttpPatch("refunds/{refundId:guid}/status")]
    [ProducesResponseType(typeof(AdminRefundDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status409Conflict)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status423Locked)]
    public async Task<IActionResult> UpdateRefundStatus(
        Guid refundId,
        UpdateRefundStatusRequest request,
        CancellationToken cancellationToken)
    {
        Result<AdminRefundDto> result = await _platformAdminService.UpdateRefundStatusAsync(refundId, request, cancellationToken);
        return result.IsFailure ? ToProblem(result.Error) : Ok(result.Value);
    }

    private ObjectResult ToProblem(ResultError error)
    {
        int statusCode = error.Code switch
        {
            "PlatformAdmin.Forbidden" => StatusCodes.Status403Forbidden,
            "PlatformAdmin.UserNotFound" => StatusCodes.Status404NotFound,
            "PlatformAdmin.InvalidUserStatus" => StatusCodes.Status409Conflict,
            "PlatformAdmin.HotelNotFound" => StatusCodes.Status404NotFound,
            "PlatformAdmin.SettlementNotFound" => StatusCodes.Status404NotFound,
            "PlatformAdmin.RefundNotFound" => StatusCodes.Status404NotFound,
            "PlatformAdmin.PaymentTransactionNotFound" => StatusCodes.Status404NotFound,
            "PlatformAdmin.InvalidHotelReviewState" => StatusCodes.Status409Conflict,
            "PlatformAdmin.SettlementNotEligible" => StatusCodes.Status409Conflict,
            "PlatformAdmin.InvalidSettlementStatus" => StatusCodes.Status409Conflict,
            "PlatformAdmin.InvalidRefundStatus" => StatusCodes.Status409Conflict,
            "PlatformAdmin.InvalidReconciliationStatus" => StatusCodes.Status409Conflict,
            "PlatformAdmin.LockUnavailable" => StatusCodes.Status423Locked,
            _ => StatusCodes.Status400BadRequest
        };

        return this.ToProblemResult(error, statusCode);
    }
}
