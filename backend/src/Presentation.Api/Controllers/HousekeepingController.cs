using HotelMarketplace.Application.Housekeeping;
using HotelMarketplace.Application.Housekeeping.Dtos;
using HotelMarketplace.Application.Housekeeping.Requests;
using HotelMarketplace.Domain.Enums;
using HotelMarketplace.Presentation.Api.Authorization;
using HotelMarketplace.SharedKernel.Results;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace HotelMarketplace.Presentation.Api.Controllers;

[ApiController]
[Route("api/hotels/{hotelId:guid}/housekeeping")]
[Authorize(
    Policy = AuthorizationPolicies.HotelScoped,
    Roles = nameof(UserRoleCode.HousekeepingStaff) + "," +
        nameof(UserRoleCode.HotelManager) + "," +
        nameof(UserRoleCode.PropertyOwner))]
public sealed class HousekeepingController : ControllerBase
{
    private readonly IHousekeepingService _housekeepingService;

    public HousekeepingController(IHousekeepingService housekeepingService)
    {
        _housekeepingService = housekeepingService;
    }

    [HttpGet("tasks")]
    [ProducesResponseType(typeof(IReadOnlyCollection<HousekeepingTaskDto>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> GetTasks(
        Guid hotelId,
        [FromQuery] HousekeepingTaskStatus? status,
        [FromQuery] Guid? assignedToUserAccountId,
        CancellationToken cancellationToken)
    {
        Result<IReadOnlyCollection<HousekeepingTaskDto>> result = await _housekeepingService.GetTasksAsync(
            hotelId,
            new HousekeepingTaskQueryRequest(status, assignedToUserAccountId),
            cancellationToken);

        return result.IsFailure ? ToProblem(result.Error) : Ok(result.Value);
    }

    [HttpPatch("tasks/{taskId:guid}/status")]
    [ProducesResponseType(typeof(HousekeepingTaskDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status409Conflict)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status423Locked)]
    public async Task<IActionResult> UpdateTaskStatus(
        Guid hotelId,
        Guid taskId,
        UpdateHousekeepingTaskStatusRequest request,
        CancellationToken cancellationToken)
    {
        Result<HousekeepingTaskDto> result = await _housekeepingService.UpdateTaskStatusAsync(
            hotelId,
            taskId,
            request,
            cancellationToken);

        return result.IsFailure ? ToProblem(result.Error) : Ok(result.Value);
    }

    [HttpPatch("tasks/{taskId:guid}/assignee")]
    [Authorize(Roles = nameof(UserRoleCode.HotelManager) + "," +
        nameof(UserRoleCode.PropertyOwner))]
    [ProducesResponseType(typeof(HousekeepingTaskDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status409Conflict)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status423Locked)]
    public async Task<IActionResult> AssignTask(
        Guid hotelId,
        Guid taskId,
        AssignHousekeepingTaskRequest request,
        CancellationToken cancellationToken)
    {
        Result<HousekeepingTaskDto> result = await _housekeepingService.AssignTaskAsync(
            hotelId,
            taskId,
            request,
            cancellationToken);

        return result.IsFailure ? ToProblem(result.Error) : Ok(result.Value);
    }

    [HttpPost("tasks/{taskId:guid}/inspection")]
    [Authorize(Roles = nameof(UserRoleCode.HotelManager) + "," + nameof(UserRoleCode.PropertyOwner))]
    [ProducesResponseType(typeof(HousekeepingTaskDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status409Conflict)]
    public async Task<IActionResult> CompleteInspection(
        Guid hotelId,
        Guid taskId,
        CancellationToken cancellationToken)
    {
        Result<HousekeepingTaskDto> result = await _housekeepingService.CompleteInspectionAsync(
            hotelId,
            taskId,
            cancellationToken);

        return result.IsFailure ? ToProblem(result.Error) : Ok(result.Value);
    }

    private ObjectResult ToProblem(ResultError error)
    {
        int statusCode = error.Code switch
        {
            "Housekeeping.Forbidden" => StatusCodes.Status403Forbidden,
            "Housekeeping.TaskNotFound" => StatusCodes.Status404NotFound,
            "Housekeeping.RoomNotFound" => StatusCodes.Status404NotFound,
            "Housekeeping.AssigneeNotFound" => StatusCodes.Status404NotFound,
            "Housekeeping.InvalidTransition" => StatusCodes.Status409Conflict,
            "Housekeeping.AssigneeOwnershipConflict" => StatusCodes.Status409Conflict,
            "Housekeeping.LockUnavailable" => StatusCodes.Status423Locked,
            _ => StatusCodes.Status400BadRequest
        };

        return this.ToProblemResult(error, statusCode);
    }
}
