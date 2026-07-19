using HotelMarketplace.Application.CustomerEngagement.Dtos;

namespace HotelMarketplace.Application.CustomerEngagement;

public interface ICustomerEngagementRepository
{
    Task<IReadOnlyCollection<SavedHotelDto>> GetSavedHotelsAsync(Guid userAccountId, CancellationToken cancellationToken);
    Task<SavedHotelDto?> SaveHotelAsync(Guid userAccountId, Guid hotelId, DateTime utcNow, CancellationToken cancellationToken);
    Task RemoveSavedHotelAsync(Guid userAccountId, Guid hotelId, CancellationToken cancellationToken);
    Task<IReadOnlyCollection<AccountNotificationDto>> GetNotificationsAsync(Guid userAccountId, int limit, CancellationToken cancellationToken);
    Task<bool> MarkNotificationReadAsync(Guid userAccountId, Guid notificationId, DateTime utcNow, CancellationToken cancellationToken);
    Task<int> MarkAllNotificationsReadAsync(Guid userAccountId, DateTime utcNow, CancellationToken cancellationToken);
}
