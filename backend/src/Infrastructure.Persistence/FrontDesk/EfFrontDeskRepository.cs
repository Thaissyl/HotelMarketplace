using System.Data;
using System.Globalization;
using HotelMarketplace.Application.FrontDesk;
using HotelMarketplace.Application.FrontDesk.Dtos;
using HotelMarketplace.Application.FrontDesk.Requests;
using HotelMarketplace.Application.Inventory;
using HotelMarketplace.Domain.Entities;
using HotelMarketplace.Domain.Enums;
using HotelMarketplace.Domain.Security;
using HotelMarketplace.Infrastructure.Persistence.Common;
using HotelMarketplace.SharedKernel.Time;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;

namespace HotelMarketplace.Infrastructure.Persistence.FrontDesk;

internal sealed class EfFrontDeskRepository : IFrontDeskRepository
{
    private readonly HotelMarketplaceDbContext _dbContext;
    private readonly IDateTimeProvider _dateTimeProvider;
    private readonly IInventoryCommitmentCoordinator _inventoryCommitmentCoordinator;
    private readonly NoShowPolicyOptions _noShowPolicyOptions;

    public EfFrontDeskRepository(
        HotelMarketplaceDbContext dbContext,
        IDateTimeProvider dateTimeProvider,
        IInventoryCommitmentCoordinator inventoryCommitmentCoordinator,
        NoShowPolicyOptions noShowPolicyOptions)
    {
        _dbContext = dbContext;
        _dateTimeProvider = dateTimeProvider;
        _inventoryCommitmentCoordinator = inventoryCommitmentCoordinator;
        _noShowPolicyOptions = noShowPolicyOptions;
    }

    public async Task<IReadOnlyCollection<PhysicalRoom>> GetPhysicalRoomsAsync(
        Guid hotelId,
        Guid? roomTypeId,
        CancellationToken cancellationToken)
    {
        IQueryable<PhysicalRoom> query = _dbContext.PhysicalRooms
            .IgnoreQueryFilters()
            .AsNoTracking()
            .Where(room => room.HotelId == hotelId);

        if (roomTypeId is not null)
        {
            query = query.Where(room => room.RoomTypeId == roomTypeId);
        }

        return await query
            .OrderBy(room => room.RoomNumber)
            .ToArrayAsync(cancellationToken);
    }

    public async Task<IReadOnlyCollection<FrontDeskBookingSummaryDto>> GetBookingsAsync(
        Guid hotelId,
        BookingStatus? status,
        DateOnly? fromDate,
        DateOnly? toDate,
        CancellationToken cancellationToken)
    {
        IQueryable<Booking> bookingsQuery = _dbContext.Bookings
            .IgnoreQueryFilters()
            .AsNoTracking()
            .Where(booking => booking.HotelId == hotelId);

        if (status is not null)
        {
            bookingsQuery = bookingsQuery.Where(booking => booking.Status == status);
        }

        if (fromDate is not null)
        {
            bookingsQuery = bookingsQuery.Where(booking => booking.CheckOutDate >= fromDate);
        }

        if (toDate is not null)
        {
            bookingsQuery = bookingsQuery.Where(booking => booking.CheckInDate <= toDate);
        }

        List<FrontDeskBookingSummaryBase> baseRows = await (
            from booking in bookingsQuery
            join bookingRoom in _dbContext.BookingRooms.IgnoreQueryFilters().AsNoTracking()
                on booking.Id equals bookingRoom.BookingId
            join roomType in _dbContext.RoomTypes.IgnoreQueryFilters().AsNoTracking()
                on bookingRoom.RoomTypeId equals roomType.Id
            join stayRecord in _dbContext.GuestStayRecords.IgnoreQueryFilters().AsNoTracking()
                on booking.Id equals stayRecord.BookingId into stayRecords
            from stayRecord in stayRecords.DefaultIfEmpty()
            join invoice in _dbContext.Invoices.IgnoreQueryFilters().AsNoTracking()
                on booking.Id equals invoice.BookingId into invoices
            from invoice in invoices.DefaultIfEmpty()
            orderby booking.CheckInDate, booking.GuestFullName
            select new FrontDeskBookingSummaryBase(
                booking.Id,
                booking.BookingCode,
                booking.HotelId,
                booking.Status,
                booking.PaymentMode,
                booking.Source,
                booking.CheckInDate,
                booking.CheckOutDate,
                booking.GuestCount,
                booking.TotalAmount,
                booking.GuestFullName,
                booking.GuestPhone,
                bookingRoom.RoomTypeId,
                roomType.Name,
                bookingRoom.Quantity,
                bookingRoom.Nights,
                stayRecord == null ? null : stayRecord.Id,
                invoice == null ? null : invoice.Id,
                booking.CreatedAtUtc))
            .Take(100)
            .ToListAsync(cancellationToken);

        if (baseRows.Count == 0)
        {
            return Array.Empty<FrontDeskBookingSummaryDto>();
        }

        List<Guid> bookingIds = baseRows.Select(row => row.BookingId).ToList();
        List<AssignedPhysicalRoomWithBookingDto> assignedRooms = await (
            from assignment in _dbContext.BookingRoomAssignments.IgnoreQueryFilters().AsNoTracking()
            join room in _dbContext.PhysicalRooms.IgnoreQueryFilters().AsNoTracking()
                on assignment.PhysicalRoomId equals room.Id
            where bookingIds.Contains(assignment.BookingId)
            orderby room.RoomNumber
            select new AssignedPhysicalRoomWithBookingDto(
                assignment.BookingId,
                room.Id,
                room.RoomNumber,
                room.RoomTypeId,
                room.Status))
            .ToListAsync(cancellationToken);

        Dictionary<Guid, AssignedPhysicalRoomDto[]> roomsByBooking = assignedRooms
            .GroupBy(room => room.BookingId)
            .ToDictionary(
                group => group.Key,
                group => group
                    .Select(room => new AssignedPhysicalRoomDto(
                        room.PhysicalRoomId,
                        room.RoomNumber,
                        room.RoomTypeId,
                        room.Status))
                    .ToArray());

        return baseRows
            .Select(row => new FrontDeskBookingSummaryDto(
                row.BookingId,
                row.BookingCode,
                row.HotelId,
                row.Status,
                row.PaymentMode,
                row.Source,
                row.CheckInDate,
                row.CheckOutDate,
                row.GuestCount,
                row.TotalAmount,
                row.GuestFullName,
                row.GuestPhone,
                row.RoomTypeId,
                row.RoomTypeName,
                row.RoomQuantity,
                row.Nights,
                roomsByBooking.TryGetValue(row.BookingId, out AssignedPhysicalRoomDto[]? rooms)
                    ? rooms
                    : Array.Empty<AssignedPhysicalRoomDto>(),
                row.GuestStayRecordId,
                row.InvoiceId,
                row.CreatedAtUtc))
            .ToArray();
    }

    public async Task<FrontDeskPersistenceResult> CheckInBookingAsync(
        Guid hotelId,
        Guid bookingId,
        Guid actorUserAccountId,
        CheckInBookingRequest request,
        CancellationToken cancellationToken)
    {
        IExecutionStrategy executionStrategy = _dbContext.Database.CreateExecutionStrategy();

        return await executionStrategy.ExecuteAsync(async () =>
        {
            await using IDbContextTransaction transaction = await _dbContext.Database.BeginTransactionAsync(
                IsolationLevel.Serializable,
                cancellationToken);

            bool bookingLockAcquired = await SqlApplicationLock.AcquireBookingLockAsync(
                _dbContext,
                bookingId,
                cancellationToken);
            if (!bookingLockAcquired)
            {
                await transaction.RollbackAsync(cancellationToken);
                return FrontDeskPersistenceResult.Failure(FrontDeskPersistenceStatus.LockUnavailable);
            }

            Booking? booking = await _dbContext.Bookings
                .IgnoreQueryFilters()
                .Include(booking => booking.Rooms)
                .FirstOrDefaultAsync(entity => entity.Id == bookingId && entity.HotelId == hotelId, cancellationToken);

            if (booking is null)
            {
                await transaction.RollbackAsync(cancellationToken);
                return FrontDeskPersistenceResult.Failure(FrontDeskPersistenceStatus.BookingNotFound);
            }

            if (booking.Status != BookingStatus.Confirmed)
            {
                await transaction.RollbackAsync(cancellationToken);
                return FrontDeskPersistenceResult.Failure(FrontDeskPersistenceStatus.InvalidBookingStatusForCheckIn);
            }

            if (booking.CheckInDate != _dateTimeProvider.Today)
            {
                await transaction.RollbackAsync(cancellationToken);
                return FrontDeskPersistenceResult.Failure(FrontDeskPersistenceStatus.CheckInDateNotReached);
            }

            if (booking.Rooms.Count != 1)
            {
                await transaction.RollbackAsync(cancellationToken);
                return FrontDeskPersistenceResult.Failure(FrontDeskPersistenceStatus.InvalidRoomAssignment);
            }

            BookingRoom bookingRoom = booking.Rooms.First();
            List<BookingRoomAssignment> existingAssignments = await _dbContext.BookingRoomAssignments
                .IgnoreQueryFilters()
                .Where(assignment => assignment.BookingId == booking.Id && assignment.Status == RecordStatus.Active)
                .ToListAsync(cancellationToken);
            List<Guid> requestedRoomIds = request.PhysicalRoomIds.Count > 0
                ? request.PhysicalRoomIds.Distinct().ToList()
                : existingAssignments.Select(assignment => assignment.PhysicalRoomId).Distinct().ToList();
            if (existingAssignments.Count > 0 &&
                !requestedRoomIds.ToHashSet().SetEquals(existingAssignments.Select(assignment => assignment.PhysicalRoomId)))
            {
                await transaction.RollbackAsync(cancellationToken);
                return FrontDeskPersistenceResult.Failure(FrontDeskPersistenceStatus.InvalidRoomAssignment);
            }
            if (requestedRoomIds.Count != bookingRoom.Quantity)
            {
                await transaction.RollbackAsync(cancellationToken);
                return FrontDeskPersistenceResult.Failure(FrontDeskPersistenceStatus.InvalidRoomAssignment);
            }

            bool inventoryLockAcquired = await _inventoryCommitmentCoordinator.AcquireRoomTypeLockAsync(
                hotelId,
                bookingRoom.RoomTypeId,
                cancellationToken);
            if (!inventoryLockAcquired)
            {
                await transaction.RollbackAsync(cancellationToken);
                return FrontDeskPersistenceResult.Failure(FrontDeskPersistenceStatus.LockUnavailable);
            }

            bool roomLocksAcquired = await SqlApplicationLock.AcquireRoomLocksAsync(
                _dbContext,
                hotelId,
                requestedRoomIds,
                cancellationToken);
            if (!roomLocksAcquired)
            {
                await transaction.RollbackAsync(cancellationToken);
                return FrontDeskPersistenceResult.Failure(FrontDeskPersistenceStatus.LockUnavailable);
            }

            List<PhysicalRoom> rooms = await _dbContext.PhysicalRooms
                .IgnoreQueryFilters()
                .Where(room => requestedRoomIds.Contains(room.Id))
                .ToListAsync(cancellationToken);

            HashSet<Guid> preAssignedRoomIds = existingAssignments
                .Select(assignment => assignment.PhysicalRoomId)
                .ToHashSet();
            if (!RoomsMatchBooking(hotelId, bookingRoom.RoomTypeId, requestedRoomIds, rooms, preAssignedRoomIds))
            {
                await transaction.RollbackAsync(cancellationToken);
                return FrontDeskPersistenceResult.Failure(FrontDeskPersistenceStatus.InvalidRoomAssignment);
            }

            bool hasOverlap = await HasActiveAssignmentOverlapAsync(
                requestedRoomIds,
                booking.CheckInDate,
                booking.CheckOutDate,
                booking.Id,
                cancellationToken);

            if (hasOverlap)
            {
                await transaction.RollbackAsync(cancellationToken);
                return FrontDeskPersistenceResult.Failure(FrontDeskPersistenceStatus.RoomAssignmentOverlap);
            }

            foreach (PhysicalRoom room in rooms)
            {
                RoomOperationalStatus oldStatus = room.Status;
                room.MarkOccupiedForCheckIn();
                await _dbContext.RoomStatusHistories.AddAsync(
                    new RoomStatusHistory(Guid.NewGuid(), hotelId, room.Id, oldStatus, room.Status, actorUserAccountId),
                    cancellationToken);

                if (!preAssignedRoomIds.Contains(room.Id))
                {
                    await _dbContext.BookingRoomAssignments.AddAsync(
                        new BookingRoomAssignment(
                            Guid.NewGuid(),
                            hotelId,
                            booking.Id,
                            bookingRoom.Id,
                            room.Id,
                            booking.CheckInDate,
                            booking.CheckOutDate,
                            actorUserAccountId),
                        cancellationToken);
                }
            }

            booking.CheckIn();

            GuestStayRecord stayRecord = new(
                Guid.NewGuid(),
                hotelId,
                booking.Id,
                actorUserAccountId,
                request.GuestFullName,
                request.IdentityDocumentType,
                request.IdentityDocumentNumber,
                request.IdentityIssuingCountry,
                request.IdentityExpiryDate);

            await _dbContext.GuestStayRecords.AddAsync(stayRecord, cancellationToken);
            await _dbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);

            return FrontDeskPersistenceResult.Success(await ToFrontDeskBookingDtoAsync(booking.Id, stayRecord.Id, null, cancellationToken));
        });
    }

    public async Task<FrontDeskPersistenceResult> AssignBookingRoomsAsync(
        Guid hotelId,
        Guid bookingId,
        Guid actorUserAccountId,
        AssignBookingRoomsRequest request,
        CancellationToken cancellationToken)
    {
        IExecutionStrategy executionStrategy = _dbContext.Database.CreateExecutionStrategy();

        return await executionStrategy.ExecuteAsync(async () =>
        {
            await using IDbContextTransaction transaction = await _dbContext.Database.BeginTransactionAsync(
                IsolationLevel.Serializable,
                cancellationToken);

            if (!await SqlApplicationLock.AcquireBookingLockAsync(_dbContext, bookingId, cancellationToken))
            {
                await transaction.RollbackAsync(cancellationToken);
                return FrontDeskPersistenceResult.Failure(FrontDeskPersistenceStatus.LockUnavailable);
            }

            Booking? booking = await _dbContext.Bookings
                .IgnoreQueryFilters()
                .Include(entity => entity.Rooms)
                .FirstOrDefaultAsync(entity => entity.Id == bookingId && entity.HotelId == hotelId, cancellationToken);
            if (booking is null)
            {
                await transaction.RollbackAsync(cancellationToken);
                return FrontDeskPersistenceResult.Failure(FrontDeskPersistenceStatus.BookingNotFound);
            }

            if (booking.Status != BookingStatus.Confirmed || booking.Rooms.Count != 1)
            {
                await transaction.RollbackAsync(cancellationToken);
                return FrontDeskPersistenceResult.Failure(FrontDeskPersistenceStatus.InvalidBookingStatusForCheckIn);
            }

            BookingRoom bookingRoom = booking.Rooms.Single();
            List<Guid> requestedRoomIds = request.PhysicalRoomIds.Distinct().ToList();
            if (requestedRoomIds.Count != bookingRoom.Quantity)
            {
                await transaction.RollbackAsync(cancellationToken);
                return FrontDeskPersistenceResult.Failure(FrontDeskPersistenceStatus.InvalidRoomAssignment);
            }

            if (!await _inventoryCommitmentCoordinator.AcquireRoomTypeLockAsync(hotelId, bookingRoom.RoomTypeId, cancellationToken))
            {
                await transaction.RollbackAsync(cancellationToken);
                return FrontDeskPersistenceResult.Failure(FrontDeskPersistenceStatus.LockUnavailable);
            }

            List<BookingRoomAssignment> currentAssignments = await _dbContext.BookingRoomAssignments
                .IgnoreQueryFilters()
                .Where(assignment => assignment.BookingId == bookingId && assignment.Status == RecordStatus.Active)
                .ToListAsync(cancellationToken);
            List<Guid> currentRoomIds = currentAssignments.Select(assignment => assignment.PhysicalRoomId).ToList();
            List<Guid> allRoomIds = requestedRoomIds.Concat(currentRoomIds).Distinct().ToList();
            if (!await SqlApplicationLock.AcquireRoomLocksAsync(_dbContext, hotelId, allRoomIds, cancellationToken))
            {
                await transaction.RollbackAsync(cancellationToken);
                return FrontDeskPersistenceResult.Failure(FrontDeskPersistenceStatus.LockUnavailable);
            }

            List<PhysicalRoom> rooms = await _dbContext.PhysicalRooms
                .IgnoreQueryFilters()
                .Where(room => allRoomIds.Contains(room.Id))
                .ToListAsync(cancellationToken);
            Dictionary<Guid, PhysicalRoom> roomsById = rooms.ToDictionary(room => room.Id);
            HashSet<Guid> currentRoomIdSet = currentRoomIds.ToHashSet();
            if (!RoomsMatchBooking(hotelId, bookingRoom.RoomTypeId, requestedRoomIds, rooms.Where(room => requestedRoomIds.Contains(room.Id)).ToList(), currentRoomIdSet))
            {
                await transaction.RollbackAsync(cancellationToken);
                return FrontDeskPersistenceResult.Failure(FrontDeskPersistenceStatus.InvalidRoomAssignment);
            }

            if (await HasActiveAssignmentOverlapAsync(requestedRoomIds, booking.CheckInDate, booking.CheckOutDate, booking.Id, cancellationToken))
            {
                await transaction.RollbackAsync(cancellationToken);
                return FrontDeskPersistenceResult.Failure(FrontDeskPersistenceStatus.RoomAssignmentOverlap);
            }

            try
            {
                foreach (BookingRoomAssignment assignment in currentAssignments.Where(assignment => !requestedRoomIds.Contains(assignment.PhysicalRoomId)))
                {
                    PhysicalRoom room = roomsById[assignment.PhysicalRoomId];
                    RoomOperationalStatus oldStatus = room.Status;
                    assignment.Deactivate();
                    room.ReleaseAssignment();
                    await _dbContext.RoomStatusHistories.AddAsync(
                        new RoomStatusHistory(Guid.NewGuid(), hotelId, room.Id, oldStatus, room.Status, actorUserAccountId),
                        cancellationToken);
                }

                foreach (Guid roomId in requestedRoomIds.Where(roomId => !currentRoomIdSet.Contains(roomId)))
                {
                    PhysicalRoom room = roomsById[roomId];
                    RoomOperationalStatus oldStatus = room.Status;
                    room.AssignForStay();
                    await _dbContext.BookingRoomAssignments.AddAsync(
                        new BookingRoomAssignment(Guid.NewGuid(), hotelId, booking.Id, bookingRoom.Id, room.Id, booking.CheckInDate, booking.CheckOutDate, actorUserAccountId),
                        cancellationToken);
                    await _dbContext.RoomStatusHistories.AddAsync(
                        new RoomStatusHistory(Guid.NewGuid(), hotelId, room.Id, oldStatus, room.Status, actorUserAccountId),
                        cancellationToken);
                }
            }
            catch (SharedKernel.Exceptions.DomainException)
            {
                await transaction.RollbackAsync(cancellationToken);
                return FrontDeskPersistenceResult.Failure(FrontDeskPersistenceStatus.InvalidRoomAssignment);
            }

            await _dbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);
            return FrontDeskPersistenceResult.Success(await ToFrontDeskBookingDtoAsync(booking.Id, null, null, cancellationToken));
        });
    }

    public async Task<FrontDeskPersistenceResult> CheckOutBookingAsync(
        Guid hotelId,
        Guid bookingId,
        Guid actorUserAccountId,
        CheckOutBookingRequest request,
        CancellationToken cancellationToken)
    {
        IExecutionStrategy executionStrategy = _dbContext.Database.CreateExecutionStrategy();

        return await executionStrategy.ExecuteAsync(async () =>
        {
            await using IDbContextTransaction transaction = await _dbContext.Database.BeginTransactionAsync(
                IsolationLevel.Serializable,
                cancellationToken);

            bool bookingLockAcquired = await SqlApplicationLock.AcquireBookingLockAsync(
                _dbContext,
                bookingId,
                cancellationToken);
            if (!bookingLockAcquired)
            {
                await transaction.RollbackAsync(cancellationToken);
                return FrontDeskPersistenceResult.Failure(FrontDeskPersistenceStatus.LockUnavailable);
            }

            Booking? booking = await _dbContext.Bookings
                .IgnoreQueryFilters()
                .FirstOrDefaultAsync(entity => entity.Id == bookingId && entity.HotelId == hotelId, cancellationToken);

            if (booking is null)
            {
                await transaction.RollbackAsync(cancellationToken);
                return FrontDeskPersistenceResult.Failure(FrontDeskPersistenceStatus.BookingNotFound);
            }

            if (booking.Status != BookingStatus.CheckedIn)
            {
                await transaction.RollbackAsync(cancellationToken);
                return FrontDeskPersistenceResult.Failure(FrontDeskPersistenceStatus.InvalidBookingStatusForCheckOut);
            }

            decimal alreadyCollected = await _dbContext.PaymentCollectionRecords
                .IgnoreQueryFilters()
                .AsNoTracking()
                .Where(payment => payment.BookingId == booking.Id &&
                    (payment.Status == PaymentCollectionStatus.Partial ||
                        payment.Status == PaymentCollectionStatus.Completed))
                .SumAsync(payment => (decimal?)payment.Amount, cancellationToken) ?? 0;

            decimal outstandingBalance = booking.TotalAmount - alreadyCollected;
            if (outstandingBalance < 0)
            {
                await transaction.RollbackAsync(cancellationToken);
                return FrontDeskPersistenceResult.Failure(FrontDeskPersistenceStatus.IncorrectCashAmount);
            }

            if (booking.PaymentMode == PaymentMode.PayAtProperty &&
                (!request.ConfirmPayAtPropertyCollection || request.CashCollectedAmount != outstandingBalance))
            {
                await transaction.RollbackAsync(cancellationToken);
                return FrontDeskPersistenceResult.Failure(FrontDeskPersistenceStatus.PaymentCollectionRequired);
            }

            if (booking.PaymentMode == PaymentMode.PlatformCollect)
            {
                bool platformPaymentConfirmed = await _dbContext.PaymentTransactions
                    .IgnoreQueryFilters()
                    .AsNoTracking()
                    .AnyAsync(payment => payment.BookingId == booking.Id && payment.Status == PaymentStatus.Paid, cancellationToken);
                if (!platformPaymentConfirmed || request.CashCollectedAmount != 0)
                {
                    await transaction.RollbackAsync(cancellationToken);
                    return FrontDeskPersistenceResult.Failure(FrontDeskPersistenceStatus.IncorrectCashAmount);
                }
            }

            if (request.CashCollectedAmount > 0)
            {
                string collectionReference = request.CollectionReference!.Trim();
#pragma warning disable CA1862
                bool duplicateReference = await _dbContext.PaymentCollectionRecords
                    .IgnoreQueryFilters()
                    .AnyAsync(collection => collection.Reference == collectionReference.ToUpperInvariant(), cancellationToken);
#pragma warning restore CA1862
                if (duplicateReference)
                {
                    await transaction.RollbackAsync(cancellationToken);
                    return FrontDeskPersistenceResult.Failure(FrontDeskPersistenceStatus.IncorrectCashAmount);
                }

                await _dbContext.PaymentCollectionRecords.AddAsync(
                    new PaymentCollectionRecord(
                        Guid.NewGuid(),
                        hotelId,
                        booking.Id,
                        actorUserAccountId,
                        request.CashCollectedAmount,
                        outstandingBalance,
                        request.CollectionMethod,
                        collectionReference,
                        _dateTimeProvider.UtcNow,
                        request.CollectionNote),
                    cancellationToken);
            }

            GuestStayRecord? stayRecord = await _dbContext.GuestStayRecords
                .IgnoreQueryFilters()
                .FirstOrDefaultAsync(stay => stay.BookingId == booking.Id, cancellationToken);

            if (stayRecord is not null)
            {
                stayRecord.CheckOut(actorUserAccountId);
            }

            List<BookingRoomAssignment> assignments = await _dbContext.BookingRoomAssignments
                .IgnoreQueryFilters()
                .Where(assignment => assignment.BookingId == booking.Id && assignment.Status == RecordStatus.Active)
                .ToListAsync(cancellationToken);

            List<Guid> roomIds = assignments.Select(assignment => assignment.PhysicalRoomId).ToList();
            bool roomLocksAcquired = await SqlApplicationLock.AcquireRoomLocksAsync(
                _dbContext,
                hotelId,
                roomIds,
                cancellationToken);
            if (!roomLocksAcquired)
            {
                await transaction.RollbackAsync(cancellationToken);
                return FrontDeskPersistenceResult.Failure(FrontDeskPersistenceStatus.LockUnavailable);
            }

            List<PhysicalRoom> rooms = await _dbContext.PhysicalRooms
                .IgnoreQueryFilters()
                .Where(room => roomIds.Contains(room.Id))
                .ToListAsync(cancellationToken);

            try
            {
                foreach (PhysicalRoom room in rooms)
                {
                    RoomOperationalStatus oldStatus = room.Status;
                    room.ReleaseToHousekeeping();
                    await _dbContext.RoomStatusHistories.AddAsync(
                        new RoomStatusHistory(Guid.NewGuid(), hotelId, room.Id, oldStatus, room.Status, actorUserAccountId),
                        cancellationToken);

                    await _dbContext.HousekeepingTasks.AddAsync(
                        new HousekeepingTask(Guid.NewGuid(), hotelId, room.Id, "CheckoutCleaning", booking.Id),
                        cancellationToken);
                }
            }
            catch (SharedKernel.Exceptions.DomainException)
            {
                await transaction.RollbackAsync(cancellationToken);
                return FrontDeskPersistenceResult.Failure(FrontDeskPersistenceStatus.InvalidRoomAssignment);
            }

            foreach (BookingRoomAssignment assignment in assignments)
            {
                assignment.Deactivate();
            }

            booking.CheckOut();

            Invoice invoice = new(
                Guid.NewGuid(),
                hotelId,
                booking.Id,
                GenerateInvoiceNumber(_dateTimeProvider.UtcNow),
                booking.TotalAmount,
                booking.TotalAmount,
                0,
                _dateTimeProvider.UtcNow);

            await _dbContext.Invoices.AddAsync(invoice, cancellationToken);
            await _dbContext.AuditRecords.AddAsync(
                new AuditRecord(
                    Guid.NewGuid(),
                    actorUserAccountId,
                    "CheckOutBooking",
                    nameof(Booking),
                    booking.Id,
                    $"Booking {booking.BookingCode} checked out with a finalized zero-balance invoice.",
                    booking.HotelId),
                cancellationToken);
            await _dbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);

            return FrontDeskPersistenceResult.Success(await ToFrontDeskBookingDtoAsync(booking.Id, stayRecord?.Id, invoice.Id, cancellationToken));
        });
    }

    public async Task<FrontDeskPersistenceResult> CreateWalkInBookingAsync(
        Guid hotelId,
        Guid actorUserAccountId,
        CreateWalkInBookingRequest request,
        CancellationToken cancellationToken)
    {
        IExecutionStrategy executionStrategy = _dbContext.Database.CreateExecutionStrategy();

        return await executionStrategy.ExecuteAsync(async () =>
        {
            await using IDbContextTransaction transaction = await _dbContext.Database.BeginTransactionAsync(
                IsolationLevel.Serializable,
                cancellationToken);

            List<Guid> requestedRoomIds = request.PhysicalRoomIds?.Distinct().ToList() ?? new List<Guid>();
            bool assignRoomsNow = requestedRoomIds.Count > 0;

            RoomType? roomType = await _dbContext.RoomTypes
                .IgnoreQueryFilters()
                .AsNoTracking()
                .FirstOrDefaultAsync(roomType => roomType.Id == request.RoomTypeId &&
                    roomType.HotelId == hotelId &&
                    roomType.Status == RecordStatus.Active,
                    cancellationToken);

            if (roomType is null)
            {
                await transaction.RollbackAsync(cancellationToken);
                return FrontDeskPersistenceResult.Failure(FrontDeskPersistenceStatus.RoomTypeNotAvailable);
            }

            if ((roomType.AdultCapacity + roomType.ChildCapacity) * request.RoomCount < request.GuestCount)
            {
                await transaction.RollbackAsync(cancellationToken);
                return FrontDeskPersistenceResult.Failure(FrontDeskPersistenceStatus.CapacityExceeded);
            }

            DateTime utcNow = _dateTimeProvider.UtcNow;
            InventoryCommitmentEvaluation inventory = await _inventoryCommitmentCoordinator.AcquireAndEvaluateAsync(
                hotelId,
                roomType.Id,
                request.CheckInDate,
                request.CheckOutDate,
                request.RoomCount,
                utcNow,
                ignoredBookingId: null,
                cancellationToken);

            if (inventory.Status == InventoryCommitmentStatus.LockUnavailable)
            {
                await transaction.RollbackAsync(cancellationToken);
                return FrontDeskPersistenceResult.Failure(FrontDeskPersistenceStatus.LockUnavailable);
            }

            if (inventory.Status == InventoryCommitmentStatus.InsufficientAvailability)
            {
                await transaction.RollbackAsync(cancellationToken);
                return FrontDeskPersistenceResult.Failure(FrontDeskPersistenceStatus.InsufficientAvailability);
            }

            List<PhysicalRoom> rooms = new();
            if (assignRoomsNow)
            {
                bool roomLocksAcquired = await SqlApplicationLock.AcquireRoomLocksAsync(
                    _dbContext,
                    hotelId,
                    requestedRoomIds,
                    cancellationToken);
                if (!roomLocksAcquired)
                {
                    await transaction.RollbackAsync(cancellationToken);
                    return FrontDeskPersistenceResult.Failure(FrontDeskPersistenceStatus.LockUnavailable);
                }

                rooms = await _dbContext.PhysicalRooms
                    .IgnoreQueryFilters()
                    .Where(room => requestedRoomIds.Contains(room.Id))
                    .ToListAsync(cancellationToken);

                if (!RoomsMatchBooking(hotelId, roomType.Id, requestedRoomIds, rooms))
                {
                    await transaction.RollbackAsync(cancellationToken);
                    return FrontDeskPersistenceResult.Failure(FrontDeskPersistenceStatus.InvalidRoomAssignment);
                }

                bool hasOverlap = await HasActiveAssignmentOverlapAsync(
                    requestedRoomIds,
                    request.CheckInDate,
                    request.CheckOutDate,
                    null,
                    cancellationToken);

                if (hasOverlap)
                {
                    await transaction.RollbackAsync(cancellationToken);
                    return FrontDeskPersistenceResult.Failure(FrontDeskPersistenceStatus.RoomAssignmentOverlap);
                }
            }

            int nights = request.CheckOutDate.DayNumber - request.CheckInDate.DayNumber;
            decimal totalAmount = request.RoomCount * nights * roomType.BasePricePerNight;
            if (request.CashCollectedAmount != totalAmount)
            {
                await transaction.RollbackAsync(cancellationToken);
                return FrontDeskPersistenceResult.Failure(FrontDeskPersistenceStatus.IncorrectCashAmount);
            }

            Guid bookingId = Guid.NewGuid();
            Booking booking = new(
                bookingId,
                GenerateBookingCode(utcNow),
                SeededUserAccountIds.AnonymousWalkInCustomer,
                hotelId,
                request.CheckInDate,
                request.CheckOutDate,
                PaymentMode.PayAtProperty,
                BookingSource.WalkIn,
                totalAmount,
                request.GuestCount,
                request.GuestFullName,
                request.GuestPhone);

            CancellationPolicy? cancellationPolicy = await _dbContext.CancellationPolicies
                .IgnoreQueryFilters()
                .AsNoTracking()
                .FirstOrDefaultAsync(
                    policy => policy.HotelId == hotelId && policy.Status == RecordStatus.Active,
                    cancellationToken);
            if (cancellationPolicy is not null)
            {
                booking.ApplyCancellationPolicySnapshot(cancellationPolicy);
            }

            BookingRoom bookingRoom = new(
                Guid.NewGuid(),
                bookingId,
                roomType.Id,
                request.RoomCount,
                roomType.BasePricePerNight,
                nights);

            booking.AddRoom(bookingRoom);
            await _dbContext.Bookings.AddAsync(booking, cancellationToken);

            foreach (PhysicalRoom room in rooms)
            {
                RoomOperationalStatus oldStatus = room.Status;
                room.MarkOccupiedForCheckIn();
                await _dbContext.RoomStatusHistories.AddAsync(
                    new RoomStatusHistory(Guid.NewGuid(), hotelId, room.Id, oldStatus, room.Status, actorUserAccountId),
                    cancellationToken);

                await _dbContext.BookingRoomAssignments.AddAsync(
                    new BookingRoomAssignment(
                        Guid.NewGuid(),
                        hotelId,
                        booking.Id,
                        bookingRoom.Id,
                        room.Id,
                        booking.CheckInDate,
                        booking.CheckOutDate,
                        actorUserAccountId),
                    cancellationToken);
            }

            GuestStayRecord? stayRecord = null;
            if (assignRoomsNow)
            {
                booking.CheckIn();
                stayRecord = new GuestStayRecord(
                    Guid.NewGuid(),
                    hotelId,
                    booking.Id,
                    actorUserAccountId,
                    request.GuestFullName,
                    request.IdentityDocumentType!,
                    request.IdentityDocumentNumber!,
                    request.IdentityIssuingCountry,
                    request.IdentityExpiryDate);
                await _dbContext.GuestStayRecords.AddAsync(stayRecord, cancellationToken);
            }

            if (request.CashCollectedAmount > 0)
            {
                await _dbContext.PaymentCollectionRecords.AddAsync(
                    new PaymentCollectionRecord(
                        Guid.NewGuid(),
                        hotelId,
                        booking.Id,
                        actorUserAccountId,
                        request.CashCollectedAmount,
                        totalAmount,
                        PaymentCollectionMethod.Cash,
                        $"WALKIN-{booking.Id:N}",
                        utcNow,
                        "Cash collected during walk-in booking creation."),
                    cancellationToken);
            }

            decimal commissionRate = await _dbContext.HotelProperties
                .IgnoreQueryFilters()
                .Where(hotel => hotel.Id == hotelId)
                .Select(hotel => hotel.DefaultCommissionRate)
                .SingleAsync(cancellationToken);
            await _dbContext.CommissionRecords.AddAsync(
                new CommissionRecord(
                    Guid.NewGuid(),
                    hotelId,
                    booking.Id,
                    booking.TotalAmount,
                    commissionRate,
                    CommissionStatus.Receivable),
                cancellationToken);

            await _dbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);

            return FrontDeskPersistenceResult.Success(await ToFrontDeskBookingDtoAsync(booking.Id, stayRecord?.Id, null, cancellationToken));
        });
    }

    public async Task<PaymentCollectionPersistenceResult> GetPaymentCollectionSummaryAsync(
        Guid hotelId,
        Guid bookingId,
        CancellationToken cancellationToken)
    {
        PaymentCollectionSummaryDto? summary = await BuildPaymentCollectionSummaryAsync(
            hotelId,
            bookingId,
            cancellationToken);
        if (summary is null)
        {
            return PaymentCollectionPersistenceResult.Failure(PaymentCollectionPersistenceStatus.BookingNotFound);
        }

        return summary.PaymentMode == PaymentMode.PayAtProperty
            ? PaymentCollectionPersistenceResult.Success(summary)
            : PaymentCollectionPersistenceResult.Failure(PaymentCollectionPersistenceStatus.WrongPaymentMode);
    }

    public async Task<PaymentCollectionPersistenceResult> RecordPaymentCollectionAsync(
        Guid hotelId,
        Guid bookingId,
        Guid actorUserAccountId,
        RecordPaymentCollectionRequest request,
        CancellationToken cancellationToken)
    {
        IExecutionStrategy executionStrategy = _dbContext.Database.CreateExecutionStrategy();

        return await executionStrategy.ExecuteAsync(async () =>
        {
            await using IDbContextTransaction transaction = await _dbContext.Database.BeginTransactionAsync(
                IsolationLevel.Serializable,
                cancellationToken);

            if (!await SqlApplicationLock.AcquireBookingLockAsync(_dbContext, bookingId, cancellationToken))
            {
                await transaction.RollbackAsync(cancellationToken);
                return PaymentCollectionPersistenceResult.Failure(PaymentCollectionPersistenceStatus.LockUnavailable);
            }

            Booking? booking = await _dbContext.Bookings
                .IgnoreQueryFilters()
                .FirstOrDefaultAsync(entity => entity.Id == bookingId && entity.HotelId == hotelId, cancellationToken);
            if (booking is null)
            {
                await transaction.RollbackAsync(cancellationToken);
                return PaymentCollectionPersistenceResult.Failure(PaymentCollectionPersistenceStatus.BookingNotFound);
            }

            if (booking.PaymentMode != PaymentMode.PayAtProperty)
            {
                await transaction.RollbackAsync(cancellationToken);
                return PaymentCollectionPersistenceResult.Failure(PaymentCollectionPersistenceStatus.WrongPaymentMode);
            }

            string normalizedReference = request.Reference.Trim().ToUpperInvariant();
            PaymentCollectionRecord? existingReference = await _dbContext.PaymentCollectionRecords
                .IgnoreQueryFilters()
                .AsNoTracking()
                .FirstOrDefaultAsync(collection => collection.Reference == normalizedReference, cancellationToken);
            if (existingReference is not null)
            {
                if (existingReference.BookingId != booking.Id ||
                    existingReference.Amount != request.Amount ||
                    existingReference.Method != request.Method)
                {
                    await transaction.RollbackAsync(cancellationToken);
                    return PaymentCollectionPersistenceResult.Failure(
                        PaymentCollectionPersistenceStatus.DuplicateCollectionReference);
                }

                await transaction.CommitAsync(cancellationToken);
                return PaymentCollectionPersistenceResult.Success((await BuildPaymentCollectionSummaryAsync(
                    hotelId,
                    bookingId,
                    cancellationToken))!);
            }

            decimal collectedAmount = await _dbContext.PaymentCollectionRecords
                .IgnoreQueryFilters()
                .AsNoTracking()
                .Where(collection => collection.BookingId == booking.Id &&
                    (collection.Status == PaymentCollectionStatus.Partial ||
                        collection.Status == PaymentCollectionStatus.Completed))
                .SumAsync(collection => (decimal?)collection.Amount, cancellationToken) ?? 0m;
            decimal remainingBalance = booking.TotalAmount - collectedAmount;
            if (request.Amount <= 0 || request.Amount > remainingBalance ||
                booking.Status is not BookingStatus.Confirmed and not BookingStatus.CheckedIn)
            {
                await transaction.RollbackAsync(cancellationToken);
                return PaymentCollectionPersistenceResult.Failure(PaymentCollectionPersistenceStatus.InvalidCollectionAmount);
            }

            PaymentCollectionRecord collection = new(
                Guid.NewGuid(),
                hotelId,
                booking.Id,
                actorUserAccountId,
                request.Amount,
                remainingBalance,
                request.Method,
                normalizedReference,
                request.CollectedAtUtc,
                request.Note);
            await _dbContext.PaymentCollectionRecords.AddAsync(collection, cancellationToken);
            await _dbContext.AuditRecords.AddAsync(
                new AuditRecord(
                    Guid.NewGuid(),
                    actorUserAccountId,
                    "RecordPaymentCollection",
                    nameof(PaymentCollectionRecord),
                    collection.Id,
                    $"Recorded {collection.Amount:0.00} against booking {booking.BookingCode}; remaining balance {collection.BalanceAfter:0.00}.",
                    hotelId),
                cancellationToken);
            await _dbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);

            return PaymentCollectionPersistenceResult.Success((await BuildPaymentCollectionSummaryAsync(
                hotelId,
                bookingId,
                cancellationToken))!);
        });
    }

    public async Task<FrontDeskPersistenceResult> MarkBookingNoShowAsync(
        Guid hotelId,
        Guid bookingId,
        Guid actorUserAccountId,
        MarkBookingNoShowRequest request,
        CancellationToken cancellationToken)
    {
        IExecutionStrategy executionStrategy = _dbContext.Database.CreateExecutionStrategy();

        return await executionStrategy.ExecuteAsync(async () =>
        {
            await using IDbContextTransaction transaction = await _dbContext.Database.BeginTransactionAsync(
                IsolationLevel.Serializable,
                cancellationToken);

            bool bookingLockAcquired = await SqlApplicationLock.AcquireBookingLockAsync(
                _dbContext,
                bookingId,
                cancellationToken);
            if (!bookingLockAcquired)
            {
                await transaction.RollbackAsync(cancellationToken);
                return FrontDeskPersistenceResult.Failure(FrontDeskPersistenceStatus.LockUnavailable);
            }

            Booking? booking = await _dbContext.Bookings
                .IgnoreQueryFilters()
                .Include(entity => entity.Rooms)
                .FirstOrDefaultAsync(
                    entity => entity.Id == bookingId && entity.HotelId == hotelId,
                    cancellationToken);

            if (booking is null)
            {
                await transaction.RollbackAsync(cancellationToken);
                return FrontDeskPersistenceResult.Failure(FrontDeskPersistenceStatus.BookingNotFound);
            }

            if (booking.Status != BookingStatus.Confirmed)
            {
                await transaction.RollbackAsync(cancellationToken);
                return FrontDeskPersistenceResult.Failure(
                    FrontDeskPersistenceStatus.InvalidBookingStatusForNoShow);
            }

            DateTime utcNow = _dateTimeProvider.UtcNow;
            DateTime eligibleAtUtc = booking.CheckInDate
                .ToDateTime(TimeOnly.MinValue, DateTimeKind.Utc)
                .AddHours(_noShowPolicyOptions.EligibleAfterHours);
            if (utcNow < eligibleAtUtc)
            {
                await transaction.RollbackAsync(cancellationToken);
                return FrontDeskPersistenceResult.Failure(
                    FrontDeskPersistenceStatus.NoShowWindowNotReached);
            }

            bool inventoryLocksAcquired = await _inventoryCommitmentCoordinator.AcquireRoomTypeLocksAsync(
                booking.Rooms.Select(room => new InventoryRoomTypeKey(hotelId, room.RoomTypeId)),
                cancellationToken);
            if (!inventoryLocksAcquired)
            {
                await transaction.RollbackAsync(cancellationToken);
                return FrontDeskPersistenceResult.Failure(FrontDeskPersistenceStatus.LockUnavailable);
            }

            List<BookingRoomAssignment> assignments = await _dbContext.BookingRoomAssignments
                .IgnoreQueryFilters()
                .Where(assignment => assignment.BookingId == booking.Id && assignment.Status == RecordStatus.Active)
                .ToListAsync(cancellationToken);
            List<Guid> assignedRoomIds = assignments.Select(assignment => assignment.PhysicalRoomId).ToList();

            if (!await SqlApplicationLock.AcquireRoomLocksAsync(
                    _dbContext,
                    hotelId,
                    assignedRoomIds,
                    cancellationToken))
            {
                await transaction.RollbackAsync(cancellationToken);
                return FrontDeskPersistenceResult.Failure(FrontDeskPersistenceStatus.LockUnavailable);
            }

            List<PhysicalRoom> assignedRooms = await _dbContext.PhysicalRooms
                .IgnoreQueryFilters()
                .Where(room => assignedRoomIds.Contains(room.Id))
                .ToListAsync(cancellationToken);

            booking.MarkNoShow(request.Reason, utcNow);
            foreach (BookingRoomAssignment assignment in assignments)
            {
                assignment.Deactivate();
            }

            foreach (PhysicalRoom room in assignedRooms.Where(room => room.Status == RoomOperationalStatus.Assigned))
            {
                RoomOperationalStatus previousStatus = room.Status;
                room.ReleaseAssignment();
                await _dbContext.RoomStatusHistories.AddAsync(
                    new RoomStatusHistory(
                        Guid.NewGuid(),
                        hotelId,
                        room.Id,
                        previousStatus,
                        room.Status,
                        actorUserAccountId),
                    cancellationToken);
            }

            await _dbContext.AuditRecords.AddAsync(
                new AuditRecord(
                    Guid.NewGuid(),
                    actorUserAccountId,
                    "MarkBookingNoShow",
                    nameof(Booking),
                    booking.Id,
                    $"Booking {booking.BookingCode} marked as no-show. Reason: {booking.NoShowReason}",
                    hotelId),
                cancellationToken);
            await _dbContext.NotificationRecords.AddAsync(
                new NotificationRecord(
                    Guid.NewGuid(),
                    booking.CustomerUserAccountId,
                    "BookingMarkedNoShow",
                    nameof(Booking),
                    booking.Id,
                    $"Booking {booking.BookingCode} was marked as no-show by the hotel.",
                    hotelId),
                cancellationToken);

            await _dbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);

            return FrontDeskPersistenceResult.Success(
                await ToFrontDeskBookingDtoAsync(booking.Id, null, null, cancellationToken));
        });
    }

    private async Task<bool> HasActiveAssignmentOverlapAsync(
        IReadOnlyCollection<Guid> physicalRoomIds,
        DateOnly checkInDate,
        DateOnly checkOutDate,
        Guid? ignoredBookingId,
        CancellationToken cancellationToken)
    {
        return await _dbContext.BookingRoomAssignments
            .IgnoreQueryFilters()
            .AsNoTracking()
            .AnyAsync(assignment => physicalRoomIds.Contains(assignment.PhysicalRoomId) &&
                assignment.Status == RecordStatus.Active &&
                assignment.StartDate < checkOutDate &&
                assignment.EndDate > checkInDate &&
                (ignoredBookingId == null || assignment.BookingId != ignoredBookingId),
                cancellationToken);
    }

    private static bool RoomsMatchBooking(
        Guid hotelId,
        Guid roomTypeId,
        List<Guid> requestedRoomIds,
        List<PhysicalRoom> rooms,
        HashSet<Guid>? existingAssignmentRoomIds = null)
    {
        return rooms.Count == requestedRoomIds.Count &&
            rooms.All(room => room.HotelId == hotelId &&
                room.RoomTypeId == roomTypeId &&
                requestedRoomIds.Contains(room.Id) &&
                (room.Status == RoomOperationalStatus.Available ||
                    (room.Status == RoomOperationalStatus.Assigned && existingAssignmentRoomIds?.Contains(room.Id) == true)));
    }

    private async Task<FrontDeskBookingDto> ToFrontDeskBookingDtoAsync(
        Guid bookingId,
        Guid? guestStayRecordId,
        Guid? invoiceId,
        CancellationToken cancellationToken)
    {
        Booking booking = await _dbContext.Bookings
            .IgnoreQueryFilters()
            .AsNoTracking()
            .FirstAsync(entity => entity.Id == bookingId, cancellationToken);

        List<AssignedPhysicalRoomDto> assignedRooms = await (
            from assignment in _dbContext.BookingRoomAssignments.IgnoreQueryFilters().AsNoTracking()
            join room in _dbContext.PhysicalRooms.IgnoreQueryFilters().AsNoTracking()
                on assignment.PhysicalRoomId equals room.Id
            where assignment.BookingId == bookingId && assignment.Status == RecordStatus.Active
            orderby room.RoomNumber
            select new AssignedPhysicalRoomDto(room.Id, room.RoomNumber, room.RoomTypeId, room.Status))
            .ToListAsync(cancellationToken);

        return new FrontDeskBookingDto(
            booking.Id,
            booking.BookingCode,
            booking.HotelId,
            booking.Status,
            booking.PaymentMode,
            booking.Source,
            booking.CheckInDate,
            booking.CheckOutDate,
            booking.GuestCount,
            booking.TotalAmount,
            booking.GuestFullName,
            booking.GuestPhone,
            assignedRooms,
            guestStayRecordId,
            invoiceId);
    }

    private static string GenerateBookingCode(DateTime utcNow)
    {
        string suffix = Guid.NewGuid().ToString("N", CultureInfo.InvariantCulture)[..10].ToUpperInvariant();
        return $"WI{utcNow.ToString("yyyyMMddHHmmss", CultureInfo.InvariantCulture)}{suffix}";
    }

    private async Task<PaymentCollectionSummaryDto?> BuildPaymentCollectionSummaryAsync(
        Guid hotelId,
        Guid bookingId,
        CancellationToken cancellationToken)
    {
        var booking = await _dbContext.Bookings
            .IgnoreQueryFilters()
            .AsNoTracking()
            .Where(entity => entity.Id == bookingId && entity.HotelId == hotelId)
            .Select(entity => new
            {
                entity.Id,
                entity.BookingCode,
                entity.PaymentMode,
                entity.TotalAmount
            })
            .FirstOrDefaultAsync(cancellationToken);
        if (booking is null)
        {
            return null;
        }

        List<PaymentCollectionDto> collections = await _dbContext.PaymentCollectionRecords
            .IgnoreQueryFilters()
            .AsNoTracking()
            .Where(collection => collection.BookingId == booking.Id)
            .OrderBy(collection => collection.CollectedAtUtc)
            .Select(collection => new PaymentCollectionDto(
                collection.Id,
                collection.Amount,
                collection.BalanceBefore,
                collection.BalanceAfter,
                collection.Method,
                collection.Reference,
                collection.Note,
                collection.Status,
                collection.CollectedAtUtc,
                collection.VoidedAtUtc,
                collection.CorrectionNote))
            .ToListAsync(cancellationToken);
        decimal collectedAmount = collections
            .Where(collection => collection.Status is PaymentCollectionStatus.Partial or PaymentCollectionStatus.Completed)
            .Sum(collection => collection.Amount);
        decimal remainingBalance = booking.TotalAmount - collectedAmount;
        PaymentCollectionStatus status = remainingBalance == 0
            ? PaymentCollectionStatus.Completed
            : collectedAmount > 0
                ? PaymentCollectionStatus.Partial
                : PaymentCollectionStatus.Pending;

        return new PaymentCollectionSummaryDto(
            booking.Id,
            booking.BookingCode,
            booking.PaymentMode,
            booking.TotalAmount,
            collectedAmount,
            remainingBalance,
            status,
            collections);
    }

    private static string GenerateInvoiceNumber(DateTime utcNow)
    {
        string suffix = Guid.NewGuid().ToString("N", CultureInfo.InvariantCulture)[..8].ToUpperInvariant();
        return $"INV{utcNow.ToString("yyyyMMddHHmmss", CultureInfo.InvariantCulture)}{suffix}";
    }

    private sealed record FrontDeskBookingSummaryBase(
        Guid BookingId,
        string BookingCode,
        Guid HotelId,
        BookingStatus Status,
        PaymentMode PaymentMode,
        BookingSource Source,
        DateOnly CheckInDate,
        DateOnly CheckOutDate,
        int GuestCount,
        decimal TotalAmount,
        string GuestFullName,
        string GuestPhone,
        Guid RoomTypeId,
        string RoomTypeName,
        int RoomQuantity,
        int Nights,
        Guid? GuestStayRecordId,
        Guid? InvoiceId,
        DateTime CreatedAtUtc);

    private sealed record AssignedPhysicalRoomWithBookingDto(
        Guid BookingId,
        Guid PhysicalRoomId,
        string RoomNumber,
        Guid RoomTypeId,
        RoomOperationalStatus Status);
}
