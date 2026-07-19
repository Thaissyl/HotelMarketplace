using System.Data;
using HotelMarketplace.Application.Bookings.Expiration;
using HotelMarketplace.Application.Inventory;
using HotelMarketplace.Domain.Entities;
using HotelMarketplace.Domain.Enums;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;

namespace HotelMarketplace.Infrastructure.Persistence.Bookings;

internal sealed class EfExpiredBookingRepository : IExpiredBookingRepository
{
    private readonly HotelMarketplaceDbContext _dbContext;
    private readonly IInventoryCommitmentCoordinator _inventoryCommitmentCoordinator;

    public EfExpiredBookingRepository(
        HotelMarketplaceDbContext dbContext,
        IInventoryCommitmentCoordinator inventoryCommitmentCoordinator)
    {
        _dbContext = dbContext;
        _inventoryCommitmentCoordinator = inventoryCommitmentCoordinator;
    }

    public async Task<IReadOnlyCollection<ExpiredBookingDto>> ExpirePendingPaymentBookingsAsync(
        DateTime utcNow,
        int batchSize,
        CancellationToken cancellationToken)
    {
        IExecutionStrategy executionStrategy = _dbContext.Database.CreateExecutionStrategy();

        return await executionStrategy.ExecuteAsync(async () =>
        {
            await using IDbContextTransaction transaction = await _dbContext.Database.BeginTransactionAsync(
                IsolationLevel.Serializable,
                cancellationToken);

            Booking[] expiredBookings = await _dbContext.Bookings
                .IgnoreQueryFilters()
                .Include(booking => booking.Rooms)
                .Where(booking => booking.Status == BookingStatus.PendingPayment &&
                    booking.PaymentExpiresAtUtc != null &&
                    booking.PaymentExpiresAtUtc <= utcNow)
                .OrderBy(booking => booking.PaymentExpiresAtUtc)
                .Take(batchSize)
                .ToArrayAsync(cancellationToken);

            if (expiredBookings.Length == 0)
            {
                await transaction.CommitAsync(cancellationToken);
                return Array.Empty<ExpiredBookingDto>();
            }

            InventoryRoomTypeKey[] roomTypeKeys = expiredBookings
                .SelectMany(booking => booking.Rooms.Select(room => new InventoryRoomTypeKey(
                    booking.HotelId,
                    room.RoomTypeId)))
                .ToArray();

            bool inventoryLocksAcquired = await _inventoryCommitmentCoordinator.AcquireRoomTypeLocksAsync(
                roomTypeKeys,
                cancellationToken);
            if (!inventoryLocksAcquired)
            {
                await transaction.RollbackAsync(cancellationToken);
                return Array.Empty<ExpiredBookingDto>();
            }

            List<Guid> bookingIds = expiredBookings.Select(booking => booking.Id).ToList();

            PaymentTransaction[] openPaymentTransactions = await _dbContext.PaymentTransactions
                .IgnoreQueryFilters()
                .Where(payment => bookingIds.Contains(payment.BookingId) &&
                    (payment.Status == PaymentStatus.Pending || payment.Status == PaymentStatus.Processing))
                .ToArrayAsync(cancellationToken);

            foreach (Booking booking in expiredBookings)
            {
                booking.ExpirePaymentHold(utcNow);
            }

            foreach (PaymentTransaction paymentTransaction in openPaymentTransactions)
            {
                paymentTransaction.MarkFailed();
            }

            await _dbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);

            return expiredBookings
                .Select(booking => new ExpiredBookingDto(
                    booking.Id,
                    booking.BookingCode,
                    booking.HotelId,
                    booking.PaymentExpiresAtUtc!.Value))
                .ToArray();
        });
    }
}
