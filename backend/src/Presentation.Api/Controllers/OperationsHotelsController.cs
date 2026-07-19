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

    [HttpGet("{hotelId:guid}")]
    [Authorize(
        Policy = AuthorizationPolicies.HotelScoped,
        Roles = nameof(UserRoleCode.PropertyOwner) + "," + nameof(UserRoleCode.HotelManager))]
    [ProducesResponseType(typeof(HotelDto), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetOperationHotel(Guid hotelId, CancellationToken cancellationToken)
    {
        Result<HotelDto> result = await _hotelManagementService.GetHotelAsync(hotelId, cancellationToken);
        return result.IsFailure ? ToHotelSetupProblem(result.Error) : Ok(result.Value);
    }

    [HttpPut("{hotelId:guid}")]
    [Authorize(
        Policy = AuthorizationPolicies.HotelScoped,
        Roles = nameof(UserRoleCode.PropertyOwner) + "," + nameof(UserRoleCode.HotelManager))]
    [ProducesResponseType(typeof(HotelDto), StatusCodes.Status200OK)]
    public async Task<IActionResult> UpdateOperationHotel(
        Guid hotelId,
        UpdateHotelProfileRequest request,
        CancellationToken cancellationToken)
    {
        Result<HotelDto> result = await _hotelManagementService.UpdateHotelProfileAsync(
            hotelId,
            request,
            cancellationToken);
        return result.IsFailure ? ToHotelSetupProblem(result.Error) : Ok(result.Value);
    }

    [HttpGet("{hotelId:guid}/content")]
    [Authorize(
        Policy = AuthorizationPolicies.HotelScoped,
        Roles = nameof(UserRoleCode.PropertyOwner) + "," + nameof(UserRoleCode.HotelManager))]
    [ProducesResponseType(typeof(HotelContentDto), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetOperationHotelContent(
        Guid hotelId,
        CancellationToken cancellationToken)
    {
        Result<HotelContentDto> result = await _hotelManagementService.GetHotelContentAsync(
            hotelId,
            cancellationToken);
        return result.IsFailure ? ToHotelSetupProblem(result.Error) : Ok(result.Value);
    }

    [HttpPut("{hotelId:guid}/content")]
    [Authorize(
        Policy = AuthorizationPolicies.HotelScoped,
        Roles = nameof(UserRoleCode.PropertyOwner) + "," + nameof(UserRoleCode.HotelManager))]
    [ProducesResponseType(typeof(HotelContentDto), StatusCodes.Status200OK)]
    public async Task<IActionResult> UpdateOperationHotelContent(
        Guid hotelId,
        UpdateHotelContentRequest request,
        CancellationToken cancellationToken)
    {
        Result<HotelContentDto> result = await _hotelManagementService.UpdateHotelContentAsync(
            hotelId,
            request,
            cancellationToken);
        return result.IsFailure ? ToHotelSetupProblem(result.Error) : Ok(result.Value);
    }

    [HttpPost("{hotelId:guid}/room-types")]
    [Authorize(
        Policy = AuthorizationPolicies.HotelScoped,
        Roles = nameof(UserRoleCode.PropertyOwner) + "," + nameof(UserRoleCode.HotelManager))]
    [ProducesResponseType(typeof(RoomTypeDto), StatusCodes.Status201Created)]
    public async Task<IActionResult> CreateOperationRoomType(
        Guid hotelId,
        CreateRoomTypeRequest request,
        CancellationToken cancellationToken)
    {
        Result<RoomTypeDto> result = await _hotelManagementService.CreateRoomTypeAsync(
            hotelId,
            request,
            cancellationToken);
        return result.IsFailure
            ? ToHotelSetupProblem(result.Error)
            : CreatedAtAction(nameof(GetOperationRoomTypes), new { hotelId }, result.Value);
    }

    [HttpPut("{hotelId:guid}/room-types/{roomTypeId:guid}")]
    [Authorize(
        Policy = AuthorizationPolicies.HotelScoped,
        Roles = nameof(UserRoleCode.PropertyOwner) + "," + nameof(UserRoleCode.HotelManager))]
    [ProducesResponseType(typeof(RoomTypeDto), StatusCodes.Status200OK)]
    public async Task<IActionResult> UpdateOperationRoomType(
        Guid hotelId,
        Guid roomTypeId,
        UpdateRoomTypeRequest request,
        CancellationToken cancellationToken)
    {
        Result<RoomTypeDto> result = await _hotelManagementService.UpdateRoomTypeAsync(
            hotelId,
            roomTypeId,
            request,
            cancellationToken);
        return result.IsFailure ? ToHotelSetupProblem(result.Error) : Ok(result.Value);
    }

    [HttpDelete("{hotelId:guid}/room-types/{roomTypeId:guid}")]
    [Authorize(
        Policy = AuthorizationPolicies.HotelScoped,
        Roles = nameof(UserRoleCode.PropertyOwner) + "," + nameof(UserRoleCode.HotelManager))]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> DeactivateOperationRoomType(
        Guid hotelId,
        Guid roomTypeId,
        CancellationToken cancellationToken)
    {
        Result result = await _hotelManagementService.DeactivateRoomTypeAsync(
            hotelId,
            roomTypeId,
            cancellationToken);
        return result.IsFailure ? ToHotelSetupProblem(result.Error) : NoContent();
    }

    [HttpPost("{hotelId:guid}/physical-rooms")]
    [Authorize(
        Policy = AuthorizationPolicies.HotelScoped,
        Roles = nameof(UserRoleCode.PropertyOwner) + "," + nameof(UserRoleCode.HotelManager))]
    [ProducesResponseType(typeof(PhysicalRoomDto), StatusCodes.Status201Created)]
    public async Task<IActionResult> CreateOperationPhysicalRoom(
        Guid hotelId,
        CreatePhysicalRoomRequest request,
        CancellationToken cancellationToken)
    {
        Result<PhysicalRoomDto> result = await _hotelManagementService.CreatePhysicalRoomAsync(
            hotelId,
            request,
            cancellationToken);
        return result.IsFailure
            ? ToHotelSetupProblem(result.Error)
            : CreatedAtAction(nameof(GetOperationRoomTypes), new { hotelId }, result.Value);
    }

    [HttpPut("{hotelId:guid}/physical-rooms/{physicalRoomId:guid}")]
    [Authorize(
        Policy = AuthorizationPolicies.HotelScoped,
        Roles = nameof(UserRoleCode.PropertyOwner) + "," + nameof(UserRoleCode.HotelManager))]
    [ProducesResponseType(typeof(PhysicalRoomDto), StatusCodes.Status200OK)]
    public async Task<IActionResult> UpdateOperationPhysicalRoom(
        Guid hotelId,
        Guid physicalRoomId,
        UpdatePhysicalRoomRequest request,
        CancellationToken cancellationToken)
    {
        Result<PhysicalRoomDto> result = await _hotelManagementService.UpdatePhysicalRoomAsync(
            hotelId,
            physicalRoomId,
            request,
            cancellationToken);
        return result.IsFailure ? ToHotelSetupProblem(result.Error) : Ok(result.Value);
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

    private ObjectResult ToHotelSetupProblem(ResultError error)
    {
        int statusCode = error.Code switch
        {
            "HotelManagement.Forbidden" => StatusCodes.Status403Forbidden,
            "HotelManagement.HotelNotFound" or
            "HotelManagement.RoomTypeNotFound" or
            "HotelManagement.PhysicalRoomNotFound" => StatusCodes.Status404NotFound,
            "HotelManagement.DuplicateRoomNumber" or
            "HotelManagement.RoomTypeHasFutureBookings" or
            "HotelManagement.RoomIsOccupied" or
            "HotelManagement.OperationalLifecycleActive" => StatusCodes.Status409Conflict,
            "HotelManagement.LockUnavailable" => StatusCodes.Status423Locked,
            _ => StatusCodes.Status400BadRequest
        };

        return this.ToProblemResult(error, statusCode);
    }
}
