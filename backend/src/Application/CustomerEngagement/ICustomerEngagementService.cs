using HotelMarketplace.Application.CustomerEngagement.Dtos;
using HotelMarketplace.SharedKernel.Results;

namespace HotelMarketplace.Application.CustomerEngagement;

public interface ICustomerEngagementService
{
    Task<Result<IReadOnlyCollection<SavedHotelDto>>> GetSavedHotelsAsync(CancellationToken cancellationToken);
    Task<Result<SavedHotelDto>> SaveHotelAsync(Guid hotelId, CancellationToken cancellationToken);
    Task<Result> RemoveSavedHotelAsync(Guid hotelId, CancellationToken cancellationToken);
    Task<Result<IReadOnlyCollection<AccountNotificationDto>>> GetNotificationsAsync(int limit, CancellationToken cancellationToken);
    Task<Result> MarkNotificationReadAsync(Guid notificationId, CancellationToken cancellationToken);
    Task<Result<int>> MarkAllNotificationsReadAsync(CancellationToken cancellationToken);
}
