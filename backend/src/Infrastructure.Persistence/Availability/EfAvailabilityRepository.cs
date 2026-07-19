using System.Data;
using HotelMarketplace.Application.Availability;
using HotelMarketplace.Application.Availability.Dtos;
using HotelMarketplace.Application.Availability.Requests;
using HotelMarketplace.Application.Inventory;
using HotelMarketplace.Domain.Entities;
using HotelMarketplace.Domain.Enums;
using HotelMarketplace.Infrastructure.Persistence.Common;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;

namespace HotelMarketplace.Infrastructure.Persistence.Availability;

internal sealed class EfAvailabilityRepository : IAvailabilityRepository
{
    private static readonly BookingStatus[] ActiveBookingStatuses =
    {
        BookingStatus.Confirmed,
        BookingStatus.CheckedIn
    };

    private readonly HotelMarketplaceDbContext _dbContext;
    private readonly IInventoryCommitmentCoordinator _inventoryCoordinator;

    public EfAvailabilityRepository(
        HotelMarketplaceDbContext dbContext,
        IInventoryCommitmentCoordinator inventoryCoordinator)
    {
        _dbContext = dbContext;
        _inventoryCoordinator = inventoryCoordinator;
    }

    public async Task<AvailabilityCalendarDto?> GetCalendarAsync(
        Guid hotelId,
        AvailabilityCalendarRequest request,
        DateTime utcNow,
        CancellationToken cancellationToken)
    {
        bool hotelExists = await _dbContext.HotelProperties
            .AsNoTracking()
            .AnyAsync(hotel => hotel.Id == hotelId, cancellationToken);

        return hotelExists
            ? await BuildCalendarAsync(hotelId, request, utcNow, cancellationToken)
            : null;
    }

    public async Task<AvailabilityPersistenceResult> ApplyChangeAsync(
        Guid hotelId,
        ChangeAvailabilityRequest request,
        Guid actorUserAccountId,
        UserRoleCode actorHotelRole,
        DateTime utcNow,
        CancellationToken cancellationToken)
    {
        IExecutionStrategy executionStrategy = _dbContext.Database.CreateExecutionStrategy();

        return await executionStrategy.ExecuteAsync(async () =>
        {
            await using IDbContextTransaction transaction = await _dbContext.Database.BeginTransactionAsync(
                IsolationLevel.Serializable,
                cancellationToken);

            bool roomTypeLockAcquired = await _inventoryCoordinator.AcquireRoomTypeLockAsync(
                hotelId,
                request.RoomTypeId,
                cancellationToken);
            if (!roomTypeLockAcquired)
            {
                await transaction.RollbackAsync(cancellationToken);
                return AvailabilityPersistenceResult.Failure(AvailabilityPersistenceStatus.LockUnavailable);
            }

            bool hotelExists = await _dbContext.HotelProperties
                .AnyAsync(hotel => hotel.Id == hotelId, cancellationToken);
            if (!hotelExists)
            {
                await transaction.RollbackAsync(cancellationToken);
                return AvailabilityPersistenceResult.Failure(AvailabilityPersistenceStatus.HotelNotFound);
            }

            bool roomTypeExists = await _dbContext.RoomTypes.AnyAsync(
                roomType => roomType.HotelId == hotelId && roomType.Id == request.RoomTypeId,
                cancellationToken);
            if (!roomTypeExists)
            {
                await transaction.RollbackAsync(cancellationToken);
                return AvailabilityPersistenceResult.Failure(AvailabilityPersistenceStatus.RoomTypeNotFound);
            }

            if (request.PhysicalRoomId.HasValue)
            {
                bool roomLockAcquired = await SqlApplicationLock.AcquireRoomLocksAsync(
                    _dbContext,
                    hotelId,
                    new[] { request.PhysicalRoomId.Value },
                    cancellationToken);
                if (!roomLockAcquired)
                {
                    await transaction.RollbackAsync(cancellationToken);
                    return AvailabilityPersistenceResult.Failure(AvailabilityPersistenceStatus.LockUnavailable);
                }

                bool physicalRoomExists = await _dbContext.PhysicalRooms.AnyAsync(
                    room => room.HotelId == hotelId &&
                        room.RoomTypeId == request.RoomTypeId &&
                        room.Id == request.PhysicalRoomId.Value,
                    cancellationToken);
                if (!physicalRoomExists)
                {
                    await transaction.RollbackAsync(cancellationToken);
                    return AvailabilityPersistenceResult.Failure(AvailabilityPersistenceStatus.PhysicalRoomNotFound);
                }
            }

            if (request.Action is AvailabilityChangeAction.Close or AvailabilityChangeAction.Block &&
                await HasActiveBookingConflictAsync(hotelId, request, utcNow, cancellationToken))
            {
                await transaction.RollbackAsync(cancellationToken);
                return AvailabilityPersistenceResult.Failure(AvailabilityPersistenceStatus.ActiveBookingConflict);
            }

            await ApplyIntervalsAsync(hotelId, request, cancellationToken);

            Guid targetId = request.PhysicalRoomId ?? request.RoomTypeId;
            string scope = request.PhysicalRoomId.HasValue ? "physical room" : "room type";
            string summary = $"{actorHotelRole} applied {request.Action} to {scope} " +
                $"from {request.StartDate:yyyy-MM-dd} through {request.EndDate:yyyy-MM-dd}.";
            await _dbContext.AuditRecords.AddAsync(
                new AuditRecord(
                    Guid.NewGuid(),
                    actorUserAccountId,
                    $"Availability{request.Action}",
                    nameof(RoomAvailability),
                    targetId,
                    summary,
                    hotelId),
                cancellationToken);

            await _dbContext.SaveChangesAsync(cancellationToken);

            AvailabilityCalendarRequest calendarRequest = new(
                request.StartDate,
                request.EndDate,
                request.RoomTypeId,
                request.PhysicalRoomId);
            AvailabilityCalendarDto calendar = await BuildCalendarAsync(
                hotelId,
                calendarRequest,
                utcNow,
                cancellationToken);

            await transaction.CommitAsync(cancellationToken);
            return AvailabilityPersistenceResult.Success(calendar);
        });
    }

    private Task<bool> HasActiveBookingConflictAsync(
        Guid hotelId,
        ChangeAvailabilityRequest request,
        DateTime utcNow,
        CancellationToken cancellationToken)
    {
        return (
            from bookingRoom in _dbContext.BookingRooms.AsNoTracking()
            join booking in _dbContext.Bookings.AsNoTracking()
                on bookingRoom.BookingId equals booking.Id
            where booking.HotelId == hotelId &&
                bookingRoom.RoomTypeId == request.RoomTypeId &&
                booking.CheckInDate < request.EndDate &&
                booking.CheckOutDate > request.StartDate &&
                (ActiveBookingStatuses.Contains(booking.Status) ||
                    (booking.Status == BookingStatus.PendingPayment &&
                        (booking.PaymentExpiresAtUtc == null || booking.PaymentExpiresAtUtc > utcNow)))
            select booking.Id)
            .AnyAsync(cancellationToken);
    }

    private async Task ApplyIntervalsAsync(
        Guid hotelId,
        ChangeAvailabilityRequest request,
        CancellationToken cancellationToken)
    {
        AvailabilityStatus targetStatus = request.Action switch
        {
            AvailabilityChangeAction.Close or AvailabilityChangeAction.Open => AvailabilityStatus.Closed,
            AvailabilityChangeAction.Block or AvailabilityChangeAction.Unblock => AvailabilityStatus.Blocked,
            _ => throw new InvalidOperationException("Unsupported availability action.")
        };

        List<RoomAvailability> overlaps = await _dbContext.RoomAvailabilities
            .Where(entry => entry.HotelId == hotelId &&
                entry.RoomTypeId == request.RoomTypeId &&
                entry.PhysicalRoomId == request.PhysicalRoomId &&
                entry.Status == targetStatus &&
                entry.StartDate < request.EndDate &&
                entry.EndDate > request.StartDate)
            .ToListAsync(cancellationToken);

        bool removesBlockingInterval = request.Action is AvailabilityChangeAction.Open or AvailabilityChangeAction.Unblock;
        if (!removesBlockingInterval)
        {
            DateOnly mergedStart = overlaps.Count == 0
                ? request.StartDate
                : overlaps.Min(entry => entry.StartDate) < request.StartDate
                    ? overlaps.Min(entry => entry.StartDate)
                    : request.StartDate;
            DateOnly mergedEnd = overlaps.Count == 0
                ? request.EndDate
                : overlaps.Max(entry => entry.EndDate) > request.EndDate
                    ? overlaps.Max(entry => entry.EndDate)
                    : request.EndDate;

            _dbContext.RoomAvailabilities.RemoveRange(overlaps);
            await _dbContext.RoomAvailabilities.AddAsync(
                new RoomAvailability(
                    Guid.NewGuid(),
                    hotelId,
                    request.RoomTypeId,
                    mergedStart,
                    mergedEnd,
                    targetStatus,
                    request.PhysicalRoomId,
                    request.Reason!.Trim()),
                cancellationToken);
            return;
        }

        foreach (RoomAvailability overlap in overlaps)
        {
            _dbContext.RoomAvailabilities.Remove(overlap);

            if (overlap.StartDate < request.StartDate)
            {
                await _dbContext.RoomAvailabilities.AddAsync(
                    new RoomAvailability(
                        Guid.NewGuid(),
                        hotelId,
                        overlap.RoomTypeId,
                        overlap.StartDate,
                        request.StartDate,
                        overlap.Status,
                        overlap.PhysicalRoomId,
                        overlap.Reason),
                    cancellationToken);
            }

            if (overlap.EndDate > request.EndDate)
            {
                await _dbContext.RoomAvailabilities.AddAsync(
                    new RoomAvailability(
                        Guid.NewGuid(),
                        hotelId,
                        overlap.RoomTypeId,
                        request.EndDate,
                        overlap.EndDate,
                        overlap.Status,
                        overlap.PhysicalRoomId,
                        overlap.Reason),
                    cancellationToken);
            }
        }
    }

    private async Task<AvailabilityCalendarDto> BuildCalendarAsync(
        Guid hotelId,
        AvailabilityCalendarRequest request,
        DateTime utcNow,
        CancellationToken cancellationToken)
    {
        IQueryable<RoomType> roomTypeQuery = _dbContext.RoomTypes
            .AsNoTracking()
            .Where(roomType => roomType.HotelId == hotelId);
        if (request.RoomTypeId.HasValue)
        {
            roomTypeQuery = roomTypeQuery.Where(roomType => roomType.Id == request.RoomTypeId.Value);
        }

        var roomTypes = await roomTypeQuery
            .OrderBy(roomType => roomType.Name)
            .Select(roomType => new { roomType.Id, roomType.Name, roomType.Status })
            .ToListAsync(cancellationToken);
        List<Guid> roomTypeIds = roomTypes.Select(roomType => roomType.Id).ToList();

        IQueryable<PhysicalRoom> physicalRoomQuery = _dbContext.PhysicalRooms
            .AsNoTracking()
            .Where(room => room.HotelId == hotelId && roomTypeIds.Contains(room.RoomTypeId));
        if (request.PhysicalRoomId.HasValue)
        {
            physicalRoomQuery = physicalRoomQuery.Where(room => room.Id == request.PhysicalRoomId.Value);
        }

        List<AvailabilityPhysicalRoomProjection> physicalRooms = await physicalRoomQuery
            .OrderBy(room => room.RoomNumber)
            .Select(room => new AvailabilityPhysicalRoomProjection(
                room.Id,
                room.RoomTypeId,
                room.RoomNumber,
                room.Status))
            .ToListAsync(cancellationToken);

        List<AvailabilityEntryDto> entries = await _dbContext.RoomAvailabilities
            .AsNoTracking()
            .Where(entry => entry.HotelId == hotelId &&
                roomTypeIds.Contains(entry.RoomTypeId) &&
                (!request.PhysicalRoomId.HasValue || entry.PhysicalRoomId == request.PhysicalRoomId.Value) &&
                entry.StartDate < request.EndDate &&
                entry.EndDate > request.StartDate)
            .OrderBy(entry => entry.StartDate)
            .ThenBy(entry => entry.EndDate)
            .Select(entry => new AvailabilityEntryDto(
                entry.Id,
                entry.RoomTypeId,
                entry.PhysicalRoomId,
                entry.StartDate,
                entry.EndDate,
                entry.Status,
                entry.Reason))
            .ToListAsync(cancellationToken);

        var commitmentRows = await (
            from bookingRoom in _dbContext.BookingRooms.AsNoTracking()
            join booking in _dbContext.Bookings.AsNoTracking()
                on bookingRoom.BookingId equals booking.Id
            where booking.HotelId == hotelId &&
                roomTypeIds.Contains(bookingRoom.RoomTypeId) &&
                booking.CheckInDate < request.EndDate &&
                booking.CheckOutDate > request.StartDate &&
                (ActiveBookingStatuses.Contains(booking.Status) ||
                    (booking.Status == BookingStatus.PendingPayment &&
                        (booking.PaymentExpiresAtUtc == null || booking.PaymentExpiresAtUtc > utcNow)))
            orderby booking.CheckInDate, booking.BookingCode
            select new
            {
                BookingId = booking.Id,
                booking.BookingCode,
                bookingRoom.RoomTypeId,
                booking.CheckInDate,
                booking.CheckOutDate,
                RoomCount = bookingRoom.Quantity,
                booking.Status
            })
            .ToListAsync(cancellationToken);

        List<Guid> bookingIds = commitmentRows.Select(row => row.BookingId).Distinct().ToList();
        var assignments = await _dbContext.BookingRoomAssignments
            .AsNoTracking()
            .Where(assignment => bookingIds.Contains(assignment.BookingId))
            .Select(assignment => new { assignment.BookingId, assignment.PhysicalRoomId })
            .ToListAsync(cancellationToken);
        Dictionary<Guid, Guid[]> assignmentsByBooking = assignments
            .GroupBy(assignment => assignment.BookingId)
            .ToDictionary(
                group => group.Key,
                group => group.Select(assignment => assignment.PhysicalRoomId).Distinct().ToArray());

        AvailabilityRoomTypeDto[] roomTypeDtos = roomTypes.Select(roomType =>
            new AvailabilityRoomTypeDto(
                roomType.Id,
                roomType.Name,
                roomType.Status,
                physicalRooms
                    .Where(room => room.RoomTypeId == roomType.Id)
                    .Select(room => new AvailabilityPhysicalRoomDto(room.Id, room.RoomNumber, room.Status))
                    .ToArray()))
            .ToArray();

        AvailabilityCommitmentDto[] commitments = commitmentRows.Select(row =>
            new AvailabilityCommitmentDto(
                row.BookingId,
                row.BookingCode,
                row.RoomTypeId,
                row.CheckInDate,
                row.CheckOutDate,
                row.RoomCount,
                row.Status,
                assignmentsByBooking.GetValueOrDefault(row.BookingId, Array.Empty<Guid>())))
            .ToArray();

        return new AvailabilityCalendarDto(
            hotelId,
            request.StartDate,
            request.EndDate,
            roomTypeDtos,
            entries,
            commitments);
    }

    private sealed record AvailabilityPhysicalRoomProjection(
        Guid Id,
        Guid RoomTypeId,
        string RoomNumber,
        RoomOperationalStatus Status);
}
