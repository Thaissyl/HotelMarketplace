using HotelMarketplace.Application.Maintenance.Dtos;
using HotelMarketplace.Application.Maintenance.Requests;
using HotelMarketplace.Application.HotelManagement.Dtos;
using HotelMarketplace.SharedKernel.Results;

namespace HotelMarketplace.Application.Maintenance;

public interface IMaintenanceService
{
    Task<Result<IReadOnlyCollection<PhysicalRoomDto>>> GetRoomsAsync(
        Guid hotelId,
        Guid? roomTypeId,
        CancellationToken cancellationToken);

    Task<Result<IReadOnlyCollection<MaintenanceRequestDto>>> GetRequestsAsync(
        Guid hotelId,
        MaintenanceRequestQueryRequest request,
        CancellationToken cancellationToken);

    Task<Result<MaintenanceRequestDto>> ReportRoomIssueAsync(
        Guid hotelId,
        ReportRoomIssueRequest request,
        CancellationToken cancellationToken);

    Task<Result<MaintenanceRequestDto>> UpdateRequestStatusAsync(
        Guid hotelId,
        Guid requestId,
        UpdateMaintenanceRequestStatusRequest request,
        CancellationToken cancellationToken);

    Task<Result<MaintenanceRequestDto>> AssignRequestAsync(
        Guid hotelId,
        Guid requestId,
        AssignMaintenanceRequestRequest request,
        CancellationToken cancellationToken);
}
