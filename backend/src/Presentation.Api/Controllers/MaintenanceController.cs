using HotelMarketplace.Application.Maintenance;
using HotelMarketplace.Application.HotelManagement.Dtos;
using HotelMarketplace.Application.Maintenance.Dtos;
using HotelMarketplace.Application.Maintenance.Requests;
using HotelMarketplace.Domain.Enums;
using HotelMarketplace.Presentation.Api.Authorization;
using HotelMarketplace.SharedKernel.Results;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace HotelMarketplace.Presentation.Api.Controllers;

[ApiController]
[Route("api/hotels/{hotelId:guid}/maintenance")]
[Authorize(Policy = AuthorizationPolicies.HotelScoped)]
public sealed class MaintenanceController : ControllerBase
{
    private readonly IMaintenanceService _maintenanceService;

    public MaintenanceController(IMaintenanceService maintenanceService)
    {
        _maintenanceService = maintenanceService;
    }

    [HttpGet("rooms")]
    [Authorize(Roles = nameof(UserRoleCode.HousekeepingStaff) + "," +
        nameof(UserRoleCode.MaintenanceStaff) + "," +
        nameof(UserRoleCode.HotelManager) + "," +
        nameof(UserRoleCode.PropertyOwner))]
    [ProducesResponseType(typeof(IReadOnlyCollection<PhysicalRoomDto>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> GetRooms(
        Guid hotelId,
        CancellationToken cancellationToken)
    {
        Result<IReadOnlyCollection<PhysicalRoomDto>> result = await _maintenanceService.GetRoomsAsync(
            hotelId,
            cancellationToken);

        return result.IsFailure ? ToProblem(result.Error) : Ok(result.Value);
    }

    [HttpGet("requests")]
    [Authorize(Roles = nameof(UserRoleCode.MaintenanceStaff) + "," +
        nameof(UserRoleCode.HotelManager) + "," +
        nameof(UserRoleCode.PropertyOwner))]
    [ProducesResponseType(typeof(IReadOnlyCollection<MaintenanceRequestDto>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> GetRequests(
        Guid hotelId,
        [FromQuery] MaintenanceStatus? status,
        [FromQuery] Guid? assignedToUserAccountId,
        CancellationToken cancellationToken)
    {
        Result<IReadOnlyCollection<MaintenanceRequestDto>> result = await _maintenanceService.GetRequestsAsync(
            hotelId,
            new MaintenanceRequestQueryRequest(status, assignedToUserAccountId),
            cancellationToken);

        return result.IsFailure ? ToProblem(result.Error) : Ok(result.Value);
    }

    [HttpPost("requests")]
    [Authorize(Roles = nameof(UserRoleCode.HousekeepingStaff) + "," +
        nameof(UserRoleCode.MaintenanceStaff) + "," +
        nameof(UserRoleCode.HotelManager) + "," +
        nameof(UserRoleCode.PropertyOwner))]
    [ProducesResponseType(typeof(MaintenanceRequestDto), StatusCodes.Status201Created)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status409Conflict)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status423Locked)]
    public async Task<IActionResult> ReportRoomIssue(
        Guid hotelId,
        ReportRoomIssueRequest request,
        CancellationToken cancellationToken)
    {
        Result<MaintenanceRequestDto> result = await _maintenanceService.ReportRoomIssueAsync(
            hotelId,
            request,
            cancellationToken);

        return result.IsFailure
            ? ToProblem(result.Error)
            : CreatedAtAction(nameof(GetRequests), new { hotelId, requestId = result.Value.Id }, result.Value);
    }

    [HttpPatch("requests/{requestId:guid}/status")]
    [Authorize(Roles = nameof(UserRoleCode.MaintenanceStaff) + "," +
        nameof(UserRoleCode.HotelManager) + "," +
        nameof(UserRoleCode.PropertyOwner))]
    [ProducesResponseType(typeof(MaintenanceRequestDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status409Conflict)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status423Locked)]
    public async Task<IActionResult> UpdateRequestStatus(
        Guid hotelId,
        Guid requestId,
        UpdateMaintenanceRequestStatusRequest request,
        CancellationToken cancellationToken)
    {
        Result<MaintenanceRequestDto> result = await _maintenanceService.UpdateRequestStatusAsync(
            hotelId,
            requestId,
            request,
            cancellationToken);

        return result.IsFailure ? ToProblem(result.Error) : Ok(result.Value);
    }

    [HttpPatch("requests/{requestId:guid}/assignee")]
    [Authorize(Roles = nameof(UserRoleCode.HotelManager) + "," +
        nameof(UserRoleCode.PropertyOwner))]
    [ProducesResponseType(typeof(MaintenanceRequestDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status409Conflict)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status423Locked)]
    public async Task<IActionResult> AssignRequest(
        Guid hotelId,
        Guid requestId,
        AssignMaintenanceRequestRequest request,
        CancellationToken cancellationToken)
    {
        Result<MaintenanceRequestDto> result = await _maintenanceService.AssignRequestAsync(
            hotelId,
            requestId,
            request,
            cancellationToken);

        return result.IsFailure ? ToProblem(result.Error) : Ok(result.Value);
    }

    private ObjectResult ToProblem(ResultError error)
    {
        int statusCode = error.Code switch
        {
            "Maintenance.Forbidden" => StatusCodes.Status403Forbidden,
            "Maintenance.RequestNotFound" => StatusCodes.Status404NotFound,
            "Maintenance.RoomNotFound" => StatusCodes.Status404NotFound,
            "Maintenance.AssigneeNotFound" => StatusCodes.Status404NotFound,
            "Maintenance.InvalidTransition" => StatusCodes.Status409Conflict,
            "Maintenance.InvalidRoomStatus" => StatusCodes.Status409Conflict,
            "Maintenance.LockUnavailable" => StatusCodes.Status423Locked,
            _ => StatusCodes.Status400BadRequest
        };

        return this.ToProblemResult(error, statusCode);
    }
}
