using HotelMarketplace.Application.HotelManagement;
using HotelMarketplace.Application.HotelManagement.Dtos;
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
}
