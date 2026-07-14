using HotelMarketplace.Application.Housekeeping.Dtos;
using HotelMarketplace.Application.Housekeeping.Requests;
using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.Housekeeping;

public interface IHousekeepingRepository
{
    Task<IReadOnlyCollection<HousekeepingTaskDto>> GetTasksAsync(
        Guid hotelId,
        HousekeepingTaskQueryRequest request,
        CancellationToken cancellationToken);

    Task<HousekeepingTaskUpdateResult> UpdateTaskStatusAsync(
        Guid hotelId,
        Guid taskId,
        Guid actorUserAccountId,
        HousekeepingTaskStatus targetStatus,
        CancellationToken cancellationToken);
}
