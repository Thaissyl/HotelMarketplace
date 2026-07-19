using HotelMarketplace.Application.HotelManagement;
using HotelMarketplace.Application.HotelManagement.Dtos;
using HotelMarketplace.Application.HotelManagement.Requests;
using HotelMarketplace.Domain.Enums;
using HotelMarketplace.Presentation.Api.Authorization;
using HotelMarketplace.SharedKernel.Results;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace HotelMarketplace.Presentation.Api.Controllers;

[ApiController]
[Route("api/operations/hotels")]
[Authorize(Roles = nameof(UserRoleCode.PropertyOwner) + "," +
    nameof(UserRoleCode.HotelManager) + "," +
    nameof(UserRoleCode.Receptionist) + "," +
    nameof(UserRoleCode.HousekeepingStaff) + "," +
    nameof(UserRoleCode.MaintenanceStaff))]
public sealed class OperationsHotelsController : ControllerBase
{
    private readonly IHotelManagementService _hotelManagementService;

    public OperationsHotelsController(IHotelManagementService hotelManagementService)
    {
        _hotelManagementService = hotelManagementService;
    }

    [HttpGet]
    [ProducesResponseType(typeof(IReadOnlyCollection<HotelDto>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> GetAccessibleHotels(CancellationToken cancellationToken)
    {
        Result<IReadOnlyCollection<HotelDto>> result =
            await _hotelManagementService.GetAccessibleOperationHotelsAsync(cancellationToken);

        return result.IsFailure
            ? this.ToProblemResult(result.Error, StatusCodes.Status403Forbidden)
            : Ok(result.Value);
    }

    [HttpGet("{hotelId:guid}/room-types")]
    [Authorize(Policy = AuthorizationPolicies.HotelScoped)]
    [ProducesResponseType(typeof(IReadOnlyCollection<RoomTypeDto>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> GetOperationRoomTypes(Guid hotelId, CancellationToken cancellationToken)
    {
        Result<IReadOnlyCollection<RoomTypeDto>> result =
            await _hotelManagementService.GetOperationRoomTypesAsync(hotelId, cancellationToken);

        return result.IsFailure
            ? this.ToProblemResult(result.Error, StatusCodes.Status403Forbidden)
            : Ok(result.Value);
    }

    [HttpGet("{hotelId:guid}/staff")]
    [Authorize(
        Policy = AuthorizationPolicies.HotelScoped,
        Roles = nameof(UserRoleCode.PropertyOwner) + "," +
            nameof(UserRoleCode.HotelManager))]
    [ProducesResponseType(typeof(IReadOnlyCollection<HotelStaffMemberDto>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> GetOperationStaff(Guid hotelId, CancellationToken cancellationToken)
    {
        Result<IReadOnlyCollection<HotelStaffMemberDto>> result =
            await _hotelManagementService.GetOperationStaffAsync(hotelId, cancellationToken);

        return result.IsFailure
            ? this.ToProblemResult(result.Error, StatusCodes.Status403Forbidden)
            : Ok(result.Value);
    }

    [HttpPost("{hotelId:guid}/staff")]
    [Authorize(
        Policy = AuthorizationPolicies.HotelScoped,
        Roles = nameof(UserRoleCode.PropertyOwner) + "," + nameof(UserRoleCode.HotelManager))]
    [ProducesResponseType(typeof(HotelStaffMemberDto), StatusCodes.Status201Created)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status409Conflict)]
    public async Task<IActionResult> CreateStaff(
        Guid hotelId,
        CreateHotelStaffRequest request,
        CancellationToken cancellationToken)
    {
        Result<HotelStaffMemberDto> result = await _hotelManagementService.CreateStaffAsync(
            hotelId,
            request,
            cancellationToken);

        return result.IsFailure
            ? ToStaffProblem(result.Error)
            : CreatedAtAction(nameof(GetOperationStaff), new { hotelId }, result.Value);
    }

    [HttpPost("{hotelId:guid}/staff/attachments")]
    [Authorize(
        Policy = AuthorizationPolicies.HotelScoped,
        Roles = nameof(UserRoleCode.PropertyOwner) + "," + nameof(UserRoleCode.HotelManager))]
    [ProducesResponseType(typeof(HotelStaffMemberDto), StatusCodes.Status201Created)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status409Conflict)]
    public async Task<IActionResult> AttachStaff(
        Guid hotelId,
        AttachHotelStaffRequest request,
        CancellationToken cancellationToken)
    {
        Result<HotelStaffMemberDto> result = await _hotelManagementService.AttachStaffAsync(
            hotelId,
            request,
            cancellationToken);

        return result.IsFailure
            ? ToStaffProblem(result.Error)
            : CreatedAtAction(nameof(GetOperationStaff), new { hotelId }, result.Value);
    }

    [HttpPatch("{hotelId:guid}/staff/{assignmentId:guid}")]
    [Authorize(
        Policy = AuthorizationPolicies.HotelScoped,
        Roles = nameof(UserRoleCode.PropertyOwner) + "," + nameof(UserRoleCode.HotelManager))]
    [ProducesResponseType(typeof(HotelStaffMemberDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status409Conflict)]
    public async Task<IActionResult> UpdateStaffAssignment(
        Guid hotelId,
        Guid assignmentId,
        UpdateHotelStaffAssignmentRequest request,
        CancellationToken cancellationToken)
    {
        Result<HotelStaffMemberDto> result = await _hotelManagementService.UpdateStaffAssignmentAsync(
            hotelId,
            assignmentId,
            request,
            cancellationToken);

        return result.IsFailure ? ToStaffProblem(result.Error) : Ok(result.Value);
    }

    private ObjectResult ToStaffProblem(ResultError error)
    {
        int statusCode = error.Code switch
        {
            "HotelManagement.Forbidden" or
            "HotelManagement.SelfManagementForbidden" or
            "HotelManagement.ManagerRoleManagementForbidden" or
            "HotelManagement.StaffSystemAccountForbidden" or
            "HotelManagement.StaffPlatformAdministratorForbidden" => StatusCodes.Status403Forbidden,
            "HotelManagement.StaffNotFound" or
            "HotelManagement.StaffUserNotFound" => StatusCodes.Status404NotFound,
            "HotelManagement.DuplicateStaffEmail" or
            "HotelManagement.DuplicateStaffPhoneNumber" or
            "HotelManagement.DuplicateStaffAssignment" or
            "HotelManagement.StaffHasOpenTasks" => StatusCodes.Status409Conflict,
            "HotelManagement.LockUnavailable" => StatusCodes.Status423Locked,
            _ => StatusCodes.Status400BadRequest
        };

        return this.ToProblemResult(error, statusCode);
    }
}
