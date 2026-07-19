using HotelMarketplace.Application.HotelManagement.Dtos;
using HotelMarketplace.Application.HotelManagement.Requests;
using HotelMarketplace.SharedKernel.Results;

namespace HotelMarketplace.Application.HotelManagement;

public interface IHotelManagementService
{
    Task<Result<HotelDto>> RegisterHotelAsync(RegisterHotelRequest request, CancellationToken cancellationToken);

    Task<Result<IReadOnlyCollection<HotelDto>>> GetMyHotelsAsync(CancellationToken cancellationToken);

    Task<Result<IReadOnlyCollection<HotelDto>>> GetAccessibleOperationHotelsAsync(CancellationToken cancellationToken);

    Task<Result<HotelDto>> GetHotelAsync(Guid hotelId, CancellationToken cancellationToken);

    Task<Result<HotelDto>> UpdateHotelProfileAsync(Guid hotelId, UpdateHotelProfileRequest request, CancellationToken cancellationToken);

    Task<Result<IReadOnlyCollection<HotelStaffMemberDto>>> GetStaffAsync(Guid hotelId, CancellationToken cancellationToken);

    Task<Result<IReadOnlyCollection<HotelStaffMemberDto>>> GetOperationStaffAsync(Guid hotelId, CancellationToken cancellationToken);

    Task<Result<HotelStaffMemberDto>> CreateStaffAsync(Guid hotelId, CreateHotelStaffRequest request, CancellationToken cancellationToken);

    Task<Result<HotelStaffMemberDto>> AttachStaffAsync(Guid hotelId, AttachHotelStaffRequest request, CancellationToken cancellationToken);

    Task<Result<HotelStaffMemberDto>> UpdateStaffAssignmentAsync(
        Guid hotelId,
        Guid assignmentId,
        UpdateHotelStaffAssignmentRequest request,
        CancellationToken cancellationToken);

    Task<Result<RoomTypeDto>> CreateRoomTypeAsync(Guid hotelId, CreateRoomTypeRequest request, CancellationToken cancellationToken);

    Task<Result<IReadOnlyCollection<RoomTypeDto>>> GetRoomTypesAsync(Guid hotelId, CancellationToken cancellationToken);

    Task<Result<IReadOnlyCollection<RoomTypeDto>>> GetOperationRoomTypesAsync(Guid hotelId, CancellationToken cancellationToken);

    Task<Result<RoomTypeDto>> UpdateRoomTypeAsync(Guid hotelId, Guid roomTypeId, UpdateRoomTypeRequest request, CancellationToken cancellationToken);

    Task<Result> DeactivateRoomTypeAsync(Guid hotelId, Guid roomTypeId, CancellationToken cancellationToken);

    Task<Result<PhysicalRoomDto>> CreatePhysicalRoomAsync(Guid hotelId, CreatePhysicalRoomRequest request, CancellationToken cancellationToken);

    Task<Result<IReadOnlyCollection<PhysicalRoomDto>>> GetPhysicalRoomsAsync(Guid hotelId, Guid? roomTypeId, CancellationToken cancellationToken);

    Task<Result<PhysicalRoomDto>> UpdatePhysicalRoomAsync(Guid hotelId, Guid physicalRoomId, UpdatePhysicalRoomRequest request, CancellationToken cancellationToken);
}
