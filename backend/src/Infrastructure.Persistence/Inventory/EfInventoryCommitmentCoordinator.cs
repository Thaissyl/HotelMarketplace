using HotelMarketplace.Application.Inventory;
using HotelMarketplace.Domain.Entities;
using HotelMarketplace.Domain.Enums;
using HotelMarketplace.Infrastructure.Persistence.Common;
using Microsoft.EntityFrameworkCore;

namespace HotelMarketplace.Infrastructure.Persistence.Inventory;

internal sealed class EfInventoryCommitmentCoordinator : IInventoryCommitmentCoordinator
{
    private static readonly BookingStatus[] CommittedBookingStatuses =
    {
        BookingStatus.Confirmed,
        BookingStatus.CheckedIn
    };

    private static readonly RoomOperationalStatus[] PermanentlyUnsellableRoomStatuses =
    {
        RoomOperationalStatus.Maintenance,
        RoomOperationalStatus.OutOfService,
        RoomOperationalStatus.Blocked,
        RoomOperationalStatus.Inactive
    };

    private static readonly AvailabilityStatus[] BlockingAvailabilityStatuses =
    {
        AvailabilityStatus.Closed,
        AvailabilityStatus.Blocked
    };

    private static readonly RoomOperationalStatus[] CurrentDayTransientUnsellableStatuses =
    {
        RoomOperationalStatus.Dirty,
        RoomOperationalStatus.Cleaning,
        RoomOperationalStatus.InspectionRequired
    };

    private readonly HotelMarketplaceDbContext _dbContext;

    public EfInventoryCommitmentCoordinator(HotelMarketplaceDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    public async Task<InventoryCommitmentEvaluation> AcquireAndEvaluateAsync(
        Guid hotelId,
        Guid roomTypeId,
        DateOnly checkInDate,
        DateOnly checkOutDate,
        int requestedRoomCount,
        DateTime utcNow,
        Guid? ignoredBookingId,
        CancellationToken cancellationToken)
    {
        bool lockAcquired = await AcquireRoomTypeLockAsync(hotelId, roomTypeId, cancellationToken);
        if (!lockAcquired)
        {
            return InventoryCommitmentEvaluation.LockUnavailable();
        }

        DateOnly today = DateOnly.FromDateTime(utcNow);
        IQueryable<PhysicalRoom> sellableRooms = _dbContext.PhysicalRooms
            .IgnoreQueryFilters()
            .AsNoTracking()
            .Where(room => room.HotelId == hotelId &&
                room.RoomTypeId == roomTypeId &&
                !PermanentlyUnsellableRoomStatuses.Contains(room.Status));

        int physicalRoomCount = await sellableRooms.CountAsync(cancellationToken);

        bool roomTypeFullyBlocked = await _dbContext.RoomAvailabilities
            .IgnoreQueryFilters()
            .AsNoTracking()
            .AnyAsync(block => block.HotelId == hotelId &&
                block.RoomTypeId == roomTypeId &&
                block.PhysicalRoomId == null &&
                BlockingAvailabilityStatuses.Contains(block.Status) &&
                block.StartDate < checkOutDate &&
                block.EndDate > checkInDate,
                cancellationToken);

        if (roomTypeFullyBlocked)
        {
            return InventoryCommitmentEvaluation.Insufficient(0);
        }

        bool includeCurrentDayOperationalState = checkInDate <= today;
        int unavailablePhysicalRoomCount = await sellableRooms.CountAsync(
            room => (includeCurrentDayOperationalState &&
                    CurrentDayTransientUnsellableStatuses.Contains(room.Status)) ||
                _dbContext.RoomAvailabilities.IgnoreQueryFilters().Any(block =>
                    block.HotelId == hotelId &&
                    block.RoomTypeId == roomTypeId &&
                    block.PhysicalRoomId == room.Id &&
                    BlockingAvailabilityStatuses.Contains(block.Status) &&
                    block.StartDate < checkOutDate &&
                    block.EndDate > checkInDate),
            cancellationToken);

        int committedRoomCount = await (
            from bookingRoom in _dbContext.BookingRooms.IgnoreQueryFilters().AsNoTracking()
            join booking in _dbContext.Bookings.IgnoreQueryFilters().AsNoTracking()
                on bookingRoom.BookingId equals booking.Id
            where booking.HotelId == hotelId &&
                bookingRoom.RoomTypeId == roomTypeId &&
                booking.CheckInDate < checkOutDate &&
                booking.CheckOutDate > checkInDate &&
                (ignoredBookingId == null || booking.Id != ignoredBookingId) &&
                (CommittedBookingStatuses.Contains(booking.Status) ||
                    (booking.Status == BookingStatus.PendingPayment &&
                        (booking.PaymentExpiresAtUtc == null || booking.PaymentExpiresAtUtc > utcNow)))
            select (int?)bookingRoom.Quantity)
            .SumAsync(cancellationToken) ?? 0;

        int availableRoomCount = Math.Max(0, physicalRoomCount - unavailablePhysicalRoomCount - committedRoomCount);
        return availableRoomCount >= requestedRoomCount
            ? InventoryCommitmentEvaluation.Available(availableRoomCount)
            : InventoryCommitmentEvaluation.Insufficient(availableRoomCount);
    }

    public Task<bool> AcquireRoomTypeLockAsync(
        Guid hotelId,
        Guid roomTypeId,
        CancellationToken cancellationToken)
    {
        return SqlApplicationLock.AcquireExclusiveAsync(
            _dbContext,
            BuildLockResource(hotelId, roomTypeId),
            cancellationToken);
    }

    public async Task<bool> AcquireRoomTypeLocksAsync(
        IEnumerable<InventoryRoomTypeKey> roomTypes,
        CancellationToken cancellationToken)
    {
        InventoryRoomTypeKey[] orderedKeys = roomTypes
            .Distinct()
            .OrderBy(key => key.HotelId)
            .ThenBy(key => key.RoomTypeId)
            .ToArray();

        foreach (InventoryRoomTypeKey key in orderedKeys)
        {
            if (!await AcquireRoomTypeLockAsync(key.HotelId, key.RoomTypeId, cancellationToken))
            {
                return false;
            }
        }

        return true;
    }

    private static string BuildLockResource(Guid hotelId, Guid roomTypeId)
    {
        return $"inventory:room-type:{hotelId:N}:{roomTypeId:N}";
    }
}
