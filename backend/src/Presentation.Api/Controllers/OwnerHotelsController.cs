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
[Route("api/owner/hotels")]
[Authorize(Roles = nameof(UserRoleCode.PropertyOwner))]
public sealed class OwnerHotelsController : ControllerBase
{
    private readonly IHotelManagementService _hotelManagementService;

    public OwnerHotelsController(IHotelManagementService hotelManagementService)
    {
        _hotelManagementService = hotelManagementService;
    }

    [HttpPost]
    [ProducesResponseType(typeof(HotelDto), StatusCodes.Status201Created)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> RegisterHotel(RegisterHotelRequest request, CancellationToken cancellationToken)
    {
        Result<HotelDto> result = await _hotelManagementService.RegisterHotelAsync(request, cancellationToken);

        if (result.IsFailure)
        {
            return ToProblem(result.Error);
        }

        return CreatedAtAction(nameof(GetHotel), new { hotelId = result.Value.Id }, result.Value);
    }

    [HttpGet]
    [ProducesResponseType(typeof(IReadOnlyCollection<HotelDto>), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetMyHotels(CancellationToken cancellationToken)
    {
        Result<IReadOnlyCollection<HotelDto>> result = await _hotelManagementService.GetMyHotelsAsync(cancellationToken);

        return result.IsFailure ? ToProblem(result.Error) : Ok(result.Value);
    }

    [HttpGet("{hotelId:guid}")]
    [Authorize(Policy = AuthorizationPolicies.HotelScoped)]
    [ProducesResponseType(typeof(HotelDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetHotel(Guid hotelId, CancellationToken cancellationToken)
    {
        Result<HotelDto> result = await _hotelManagementService.GetHotelAsync(hotelId, cancellationToken);

        return result.IsFailure ? ToProblem(result.Error) : Ok(result.Value);
    }

    [HttpPut("{hotelId:guid}")]
    [Authorize(Policy = AuthorizationPolicies.HotelScoped)]
    [ProducesResponseType(typeof(HotelDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    public async Task<IActionResult> UpdateHotelProfile(
        Guid hotelId,
        UpdateHotelProfileRequest request,
        CancellationToken cancellationToken)
    {
        Result<HotelDto> result = await _hotelManagementService.UpdateHotelProfileAsync(hotelId, request, cancellationToken);

        return result.IsFailure ? ToProblem(result.Error) : Ok(result.Value);
    }

    [HttpGet("{hotelId:guid}/staff")]
    [Authorize(Policy = AuthorizationPolicies.HotelScoped)]
    [ProducesResponseType(typeof(IReadOnlyCollection<HotelStaffMemberDto>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetStaff(Guid hotelId, CancellationToken cancellationToken)
    {
        Result<IReadOnlyCollection<HotelStaffMemberDto>> result = await _hotelManagementService.GetStaffAsync(hotelId, cancellationToken);

        return result.IsFailure ? ToProblem(result.Error) : Ok(result.Value);
    }

    [HttpPost("{hotelId:guid}/staff")]
    [Authorize(Policy = AuthorizationPolicies.HotelScoped)]
    [ProducesResponseType(typeof(HotelStaffMemberDto), StatusCodes.Status201Created)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status409Conflict)]
    public async Task<IActionResult> CreateStaff(
        Guid hotelId,
        CreateHotelStaffRequest request,
        CancellationToken cancellationToken)
    {
        Result<HotelStaffMemberDto> result = await _hotelManagementService.CreateStaffAsync(hotelId, request, cancellationToken);

        return result.IsFailure
            ? ToProblem(result.Error)
            : CreatedAtAction(nameof(GetStaff), new { hotelId }, result.Value);
    }

    [HttpPost("{hotelId:guid}/room-types")]
    [Authorize(Policy = AuthorizationPolicies.HotelScoped)]
    [ProducesResponseType(typeof(RoomTypeDto), StatusCodes.Status201Created)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> CreateRoomType(
        Guid hotelId,
        CreateRoomTypeRequest request,
        CancellationToken cancellationToken)
    {
        Result<RoomTypeDto> result = await _hotelManagementService.CreateRoomTypeAsync(hotelId, request, cancellationToken);

        if (result.IsFailure)
        {
            return ToProblem(result.Error);
        }

        return CreatedAtAction(nameof(GetRoomTypes), new { hotelId }, result.Value);
    }

    [HttpGet("{hotelId:guid}/room-types")]
    [Authorize(Policy = AuthorizationPolicies.HotelScoped)]
    [ProducesResponseType(typeof(IReadOnlyCollection<RoomTypeDto>), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetRoomTypes(Guid hotelId, CancellationToken cancellationToken)
    {
        Result<IReadOnlyCollection<RoomTypeDto>> result = await _hotelManagementService.GetRoomTypesAsync(hotelId, cancellationToken);

        return result.IsFailure ? ToProblem(result.Error) : Ok(result.Value);
    }

    [HttpPut("{hotelId:guid}/room-types/{roomTypeId:guid}")]
    [Authorize(Policy = AuthorizationPolicies.HotelScoped)]
    [ProducesResponseType(typeof(RoomTypeDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    public async Task<IActionResult> UpdateRoomType(
        Guid hotelId,
        Guid roomTypeId,
        UpdateRoomTypeRequest request,
        CancellationToken cancellationToken)
    {
        Result<RoomTypeDto> result = await _hotelManagementService.UpdateRoomTypeAsync(hotelId, roomTypeId, request, cancellationToken);

        return result.IsFailure ? ToProblem(result.Error) : Ok(result.Value);
    }

    [HttpDelete("{hotelId:guid}/room-types/{roomTypeId:guid}")]
    [Authorize(Policy = AuthorizationPolicies.HotelScoped)]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status409Conflict)]
    public async Task<IActionResult> DeactivateRoomType(
        Guid hotelId,
        Guid roomTypeId,
        CancellationToken cancellationToken)
    {
        Result result = await _hotelManagementService.DeactivateRoomTypeAsync(hotelId, roomTypeId, cancellationToken);

        return result.IsFailure ? ToProblem(result.Error) : NoContent();
    }

    [HttpPost("{hotelId:guid}/physical-rooms")]
    [Authorize(Policy = AuthorizationPolicies.HotelScoped)]
    [ProducesResponseType(typeof(PhysicalRoomDto), StatusCodes.Status201Created)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status409Conflict)]
    public async Task<IActionResult> CreatePhysicalRoom(
        Guid hotelId,
        CreatePhysicalRoomRequest request,
        CancellationToken cancellationToken)
    {
        Result<PhysicalRoomDto> result = await _hotelManagementService.CreatePhysicalRoomAsync(hotelId, request, cancellationToken);

        if (result.IsFailure)
        {
            return ToProblem(result.Error);
        }

        return CreatedAtAction(nameof(GetPhysicalRooms), new { hotelId }, result.Value);
    }

    [HttpGet("{hotelId:guid}/physical-rooms")]
    [Authorize(Policy = AuthorizationPolicies.HotelScoped)]
    [ProducesResponseType(typeof(IReadOnlyCollection<PhysicalRoomDto>), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetPhysicalRooms(
        Guid hotelId,
        [FromQuery] Guid? roomTypeId,
        CancellationToken cancellationToken)
    {
        Result<IReadOnlyCollection<PhysicalRoomDto>> result = await _hotelManagementService.GetPhysicalRoomsAsync(hotelId, roomTypeId, cancellationToken);

        return result.IsFailure ? ToProblem(result.Error) : Ok(result.Value);
    }

    [HttpPut("{hotelId:guid}/physical-rooms/{physicalRoomId:guid}")]
    [Authorize(Policy = AuthorizationPolicies.HotelScoped)]
    [ProducesResponseType(typeof(PhysicalRoomDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status409Conflict)]
    public async Task<IActionResult> UpdatePhysicalRoom(
        Guid hotelId,
        Guid physicalRoomId,
        UpdatePhysicalRoomRequest request,
        CancellationToken cancellationToken)
    {
        Result<PhysicalRoomDto> result = await _hotelManagementService.UpdatePhysicalRoomAsync(hotelId, physicalRoomId, request, cancellationToken);

        return result.IsFailure ? ToProblem(result.Error) : Ok(result.Value);
    }

    private ObjectResult ToProblem(ResultError error)
    {
        int statusCode = error.Code switch
        {
            "HotelManagement.Forbidden" => StatusCodes.Status403Forbidden,
            "HotelManagement.HotelNotFound" => StatusCodes.Status404NotFound,
            "HotelManagement.RoomTypeNotFound" => StatusCodes.Status404NotFound,
            "HotelManagement.PhysicalRoomNotFound" => StatusCodes.Status404NotFound,
            "HotelManagement.DuplicateRoomNumber" => StatusCodes.Status409Conflict,
            "HotelManagement.RoomTypeHasFutureBookings" => StatusCodes.Status409Conflict,
            "HotelManagement.RoomIsOccupied" => StatusCodes.Status409Conflict,
            "HotelManagement.LockUnavailable" => StatusCodes.Status423Locked,
            "HotelManagement.DuplicateStaffEmail" => StatusCodes.Status409Conflict,
            "HotelManagement.DuplicateStaffPhoneNumber" => StatusCodes.Status409Conflict,
            "HotelManagement.InvalidStaffRole" => StatusCodes.Status400BadRequest,
            _ => StatusCodes.Status400BadRequest
        };

        return this.ToProblemResult(error, statusCode);
    }
}
