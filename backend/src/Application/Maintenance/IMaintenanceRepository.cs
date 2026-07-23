using HotelMarketplace.Application.Maintenance.Dtos;
using HotelMarketplace.Application.Maintenance.Requests;
using HotelMarketplace.Application.HotelManagement.Dtos;
using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.Maintenance;

public interface IMaintenanceRepository
{
    Task<IReadOnlyCollection<PhysicalRoomDto>> GetRoomsAsync(
        Guid hotelId,
        Guid? roomTypeId,
        CancellationToken cancellationToken);

    Task<IReadOnlyCollection<MaintenanceRequestDto>> GetRequestsAsync(
        Guid hotelId,
        MaintenanceRequestQueryRequest request,
        CancellationToken cancellationToken);

    Task<MaintenanceRequestPersistenceResult> ReportRoomIssueAsync(
        Guid hotelId,
        Guid actorUserAccountId,
        ReportRoomIssueRequest request,
        CancellationToken cancellationToken);

    Task<MaintenanceRequestPersistenceResult> UpdateRequestStatusAsync(
        Guid hotelId,
        Guid requestId,
        Guid actorUserAccountId,
        bool canOverrideAssignee,
        UpdateMaintenanceRequestStatusRequest request,
        CancellationToken cancellationToken);

    Task<MaintenanceRequestPersistenceResult> AssignRequestAsync(
        Guid hotelId,
        Guid requestId,
        Guid assignedToUserAccountId,
        CancellationToken cancellationToken);
}
