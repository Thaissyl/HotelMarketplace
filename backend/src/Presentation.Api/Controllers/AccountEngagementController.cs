using HotelMarketplace.Application.CustomerEngagement;
using HotelMarketplace.Application.CustomerEngagement.Dtos;
using HotelMarketplace.Domain.Enums;
using HotelMarketplace.SharedKernel.Results;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace HotelMarketplace.Presentation.Api.Controllers;

[ApiController]
[Route("api/account")]
[Authorize]
public sealed class AccountEngagementController : ControllerBase
{
    private readonly ICustomerEngagementService _service;

    public AccountEngagementController(ICustomerEngagementService service)
    {
        _service = service;
    }

    [HttpGet("saved-hotels")]
    [Authorize(Roles = nameof(UserRoleCode.Customer))]
    [ProducesResponseType(typeof(IReadOnlyCollection<SavedHotelDto>), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetSavedHotels(CancellationToken cancellationToken)
    {
        Result<IReadOnlyCollection<SavedHotelDto>> result = await _service.GetSavedHotelsAsync(cancellationToken);
        return result.IsFailure ? ToProblem(result.Error) : Ok(result.Value);
    }

    [HttpPut("saved-hotels/{hotelId:guid}")]
    [Authorize(Roles = nameof(UserRoleCode.Customer))]
    [ProducesResponseType(typeof(SavedHotelDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    public async Task<IActionResult> SaveHotel(Guid hotelId, CancellationToken cancellationToken)
    {
        Result<SavedHotelDto> result = await _service.SaveHotelAsync(hotelId, cancellationToken);
        return result.IsFailure ? ToProblem(result.Error) : Ok(result.Value);
    }

    [HttpDelete("saved-hotels/{hotelId:guid}")]
    [Authorize(Roles = nameof(UserRoleCode.Customer))]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> RemoveSavedHotel(Guid hotelId, CancellationToken cancellationToken)
    {
        Result result = await _service.RemoveSavedHotelAsync(hotelId, cancellationToken);
        return result.IsFailure ? ToProblem(result.Error) : NoContent();
    }

    [HttpGet("notifications")]
    [ProducesResponseType(typeof(IReadOnlyCollection<AccountNotificationDto>), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetNotifications([FromQuery] int limit = 50, CancellationToken cancellationToken = default)
    {
        Result<IReadOnlyCollection<AccountNotificationDto>> result = await _service.GetNotificationsAsync(limit, cancellationToken);
        return result.IsFailure ? ToProblem(result.Error) : Ok(result.Value);
    }

    [HttpPatch("notifications/{notificationId:guid}/read")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    public async Task<IActionResult> MarkNotificationRead(Guid notificationId, CancellationToken cancellationToken)
    {
        Result result = await _service.MarkNotificationReadAsync(notificationId, cancellationToken);
        return result.IsFailure ? ToProblem(result.Error) : NoContent();
    }

    [HttpPost("notifications/read-all")]
    [ProducesResponseType(typeof(int), StatusCodes.Status200OK)]
    public async Task<IActionResult> MarkAllNotificationsRead(CancellationToken cancellationToken)
    {
        Result<int> result = await _service.MarkAllNotificationsReadAsync(cancellationToken);
        return result.IsFailure ? ToProblem(result.Error) : Ok(result.Value);
    }

    private ObjectResult ToProblem(ResultError error)
    {
        int statusCode = error.Code switch
        {
            "CustomerEngagement.Unauthenticated" => StatusCodes.Status401Unauthorized,
            "CustomerEngagement.HotelNotFound" => StatusCodes.Status404NotFound,
            "CustomerEngagement.NotificationNotFound" => StatusCodes.Status404NotFound,
            _ => StatusCodes.Status400BadRequest
        };
        return this.ToProblemResult(error, statusCode);
    }
}
