using System.Data;
using HotelMarketplace.Application.CustomerEngagement;
using HotelMarketplace.Application.CustomerEngagement.Dtos;
using HotelMarketplace.Domain.Entities;
using HotelMarketplace.Domain.Enums;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;

namespace HotelMarketplace.Infrastructure.Persistence.CustomerEngagement;

public sealed class EfCustomerEngagementRepository : ICustomerEngagementRepository
{
    private readonly HotelMarketplaceDbContext _dbContext;

    public EfCustomerEngagementRepository(HotelMarketplaceDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    public async Task<IReadOnlyCollection<SavedHotelDto>> GetSavedHotelsAsync(
        Guid userAccountId,
        CancellationToken cancellationToken)
    {
        return await ProjectSavedHotels(userAccountId)
            .ToArrayAsync(cancellationToken);
    }

    public async Task<SavedHotelDto?> SaveHotelAsync(
        Guid userAccountId,
        Guid hotelId,
        DateTime utcNow,
        CancellationToken cancellationToken)
    {
        IExecutionStrategy executionStrategy = _dbContext.Database.CreateExecutionStrategy();
        return await executionStrategy.ExecuteAsync(async () =>
        {
            await using IDbContextTransaction transaction = await _dbContext.Database.BeginTransactionAsync(
                IsolationLevel.Serializable,
                cancellationToken);

            bool hotelExists = await _dbContext.HotelProperties
                .IgnoreQueryFilters()
                .AnyAsync(
                    hotel => hotel.Id == hotelId &&
                        hotel.ApprovalStatus == HotelApprovalStatus.Approved &&
                        hotel.PublicationStatus == PublicationStatus.Published,
                    cancellationToken);
            if (!hotelExists)
            {
                await transaction.RollbackAsync(cancellationToken);
                return null;
            }

            bool alreadySaved = await _dbContext.SavedHotels
                .AnyAsync(item => item.UserAccountId == userAccountId && item.HotelId == hotelId, cancellationToken);
            if (!alreadySaved)
            {
                _dbContext.SavedHotels.Add(new SavedHotel(Guid.NewGuid(), userAccountId, hotelId, utcNow));
                await _dbContext.SaveChangesAsync(cancellationToken);
            }

            await transaction.CommitAsync(cancellationToken);
            return await ProjectSavedHotels(userAccountId, hotelId)
                .SingleAsync(cancellationToken);
        });
    }

    public async Task RemoveSavedHotelAsync(
        Guid userAccountId,
        Guid hotelId,
        CancellationToken cancellationToken)
    {
        SavedHotel? savedHotel = await _dbContext.SavedHotels
            .SingleOrDefaultAsync(
                item => item.UserAccountId == userAccountId && item.HotelId == hotelId,
                cancellationToken);
        if (savedHotel is null)
        {
            return;
        }

        _dbContext.SavedHotels.Remove(savedHotel);
        await _dbContext.SaveChangesAsync(cancellationToken);
    }

    public async Task<IReadOnlyCollection<AccountNotificationDto>> GetNotificationsAsync(
        Guid userAccountId,
        int limit,
        CancellationToken cancellationToken)
    {
        return await _dbContext.NotificationRecords
            .IgnoreQueryFilters()
            .AsNoTracking()
            .Where(item => item.RecipientUserAccountId == userAccountId)
            .OrderByDescending(item => item.CreatedAtUtc)
            .Take(limit)
            .Select(item => new AccountNotificationDto(
                item.Id,
                item.EventType,
                item.RelatedEntityType,
                item.RelatedEntityId,
                item.Message,
                item.HotelId,
                item.CreatedAtUtc,
                item.ReadAtUtc))
            .ToArrayAsync(cancellationToken);
    }

    public async Task<bool> MarkNotificationReadAsync(
        Guid userAccountId,
        Guid notificationId,
        DateTime utcNow,
        CancellationToken cancellationToken)
    {
        NotificationRecord? notification = await _dbContext.NotificationRecords
            .IgnoreQueryFilters()
            .SingleOrDefaultAsync(
                item => item.Id == notificationId && item.RecipientUserAccountId == userAccountId,
                cancellationToken);
        if (notification is null)
        {
            return false;
        }

        notification.MarkRead(utcNow);
        await _dbContext.SaveChangesAsync(cancellationToken);
        return true;
    }

    public async Task<int> MarkAllNotificationsReadAsync(
        Guid userAccountId,
        DateTime utcNow,
        CancellationToken cancellationToken)
    {
        NotificationRecord[] notifications = await _dbContext.NotificationRecords
            .IgnoreQueryFilters()
            .Where(item => item.RecipientUserAccountId == userAccountId && item.ReadAtUtc == null)
            .ToArrayAsync(cancellationToken);
        foreach (NotificationRecord notification in notifications)
        {
            notification.MarkRead(utcNow);
        }

        if (notifications.Length > 0)
        {
            await _dbContext.SaveChangesAsync(cancellationToken);
        }

        return notifications.Length;
    }

    private IQueryable<SavedHotelDto> ProjectSavedHotels(Guid userAccountId, Guid? hotelId = null)
    {
        var query =
            from saved in _dbContext.SavedHotels.AsNoTracking()
            join hotel in _dbContext.HotelProperties.IgnoreQueryFilters().AsNoTracking()
                on saved.HotelId equals hotel.Id
            where saved.UserAccountId == userAccountId &&
                hotel.ApprovalStatus == HotelApprovalStatus.Approved &&
                hotel.PublicationStatus == PublicationStatus.Published
            select new { Saved = saved, Hotel = hotel };

        if (hotelId.HasValue)
        {
            Guid requiredHotelId = hotelId.Value;
            query = query.Where(item => item.Hotel.Id == requiredHotelId);
        }

        query = query.OrderByDescending(item => item.Saved.CreatedAtUtc);

        return query.Select(item => new SavedHotelDto(
                item.Hotel.Id,
                item.Hotel.Name,
                item.Hotel.City,
                item.Hotel.AddressLine,
                _dbContext.RoomTypes.IgnoreQueryFilters()
                    .Where(roomType => roomType.HotelId == item.Hotel.Id && roomType.Status == RecordStatus.Active)
                    .Select(roomType => (decimal?)roomType.BasePricePerNight)
                    .Min() ?? 0m,
                _dbContext.HotelImages.IgnoreQueryFilters()
                    .Where(image => image.HotelId == item.Hotel.Id && image.Status == RecordStatus.Active)
                    .OrderBy(image => image.DisplayOrder)
                    .Select(image => image.ImageUrl)
                    .FirstOrDefault(),
                item.Saved.CreatedAtUtc));
    }
}
