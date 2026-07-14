using HotelMarketplace.Application.Maintenance.Dtos;
using HotelMarketplace.Application.Maintenance.Requests;
using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.Maintenance;

public interface IMaintenanceRepository
{
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
        MaintenanceStatus targetStatus,
        CancellationToken cancellationToken);
}
