using HotelMarketplace.Application.Housekeeping.Dtos;
using HotelMarketplace.Application.Housekeeping.Requests;
using HotelMarketplace.SharedKernel.Results;

namespace HotelMarketplace.Application.Housekeeping;

public interface IHousekeepingService
{
    Task<Result<IReadOnlyCollection<HousekeepingTaskDto>>> GetTasksAsync(
        Guid hotelId,
        HousekeepingTaskQueryRequest request,
        CancellationToken cancellationToken);

    Task<Result<HousekeepingTaskDto>> UpdateTaskStatusAsync(
        Guid hotelId,
        Guid taskId,
        UpdateHousekeepingTaskStatusRequest request,
        CancellationToken cancellationToken);
}
