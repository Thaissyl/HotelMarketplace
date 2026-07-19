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

    public EfFrontDeskRepository(
        HotelMarketplaceDbContext dbContext,
        IDateTimeProvider dateTimeProvider,
        IInventoryCommitmentCoordinator inventoryCommitmentCoordinator)
    {
        _dbContext = dbContext;
        _dateTimeProvider = dateTimeProvider;
        _inventoryCommitmentCoordinator = inventoryCommitmentCoordinator;
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

            bool bookingLockAcquired = await SqlApplicationLock.AcquireExclusiveAsync(
                _dbContext,
                $"frontdesk:checkin:{hotelId:N}:{bookingId:N}",
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

            if (booking.Rooms.Count != 1)
            {
                await transaction.RollbackAsync(cancellationToken);
                return FrontDeskPersistenceResult.Failure(FrontDeskPersistenceStatus.InvalidRoomAssignment);
            }

            BookingRoom bookingRoom = booking.Rooms.First();
            List<Guid> requestedRoomIds = request.PhysicalRoomIds.Distinct().ToList();
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

            if (!RoomsMatchBooking(hotelId, bookingRoom.RoomTypeId, requestedRoomIds, rooms))
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

            booking.CheckIn();

            GuestStayRecord stayRecord = new(
                Guid.NewGuid(),
                hotelId,
                booking.Id,
                actorUserAccountId,
                request.GuestFullName,
                request.IdentityDocumentNumber);

            await _dbContext.GuestStayRecords.AddAsync(stayRecord, cancellationToken);
            await _dbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);

            return FrontDeskPersistenceResult.Success(await ToFrontDeskBookingDtoAsync(booking.Id, stayRecord.Id, null, cancellationToken));
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

            bool bookingLockAcquired = await SqlApplicationLock.AcquireExclusiveAsync(
                _dbContext,
                $"frontdesk:checkout:{hotelId:N}:{bookingId:N}",
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
                .Where(payment => payment.BookingId == booking.Id && payment.Status == PaymentStatus.Paid)
                .SumAsync(payment => (decimal?)payment.Amount, cancellationToken) ?? 0;

            if (booking.PaymentMode == PaymentMode.PayAtProperty &&
                (!request.ConfirmPayAtPropertyCollection || alreadyCollected + request.CashCollectedAmount < booking.TotalAmount))
            {
                await transaction.RollbackAsync(cancellationToken);
                return FrontDeskPersistenceResult.Failure(FrontDeskPersistenceStatus.PaymentCollectionRequired);
            }

            if (request.CashCollectedAmount > 0)
            {
                await _dbContext.PaymentCollectionRecords.AddAsync(
                    new PaymentCollectionRecord(Guid.NewGuid(), hotelId, booking.Id, actorUserAccountId, request.CashCollectedAmount),
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
                alreadyCollected + request.CashCollectedAmount);

            await _dbContext.Invoices.AddAsync(invoice, cancellationToken);
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
                request.GuestFullName,
                request.GuestPhone);

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
                    request.IdentityDocumentNumber);
                await _dbContext.GuestStayRecords.AddAsync(stayRecord, cancellationToken);
            }

            if (request.CashCollectedAmount > 0)
            {
                await _dbContext.PaymentCollectionRecords.AddAsync(
                    new PaymentCollectionRecord(Guid.NewGuid(), hotelId, booking.Id, actorUserAccountId, request.CashCollectedAmount),
                    cancellationToken);
            }

            await _dbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);

            return FrontDeskPersistenceResult.Success(await ToFrontDeskBookingDtoAsync(booking.Id, stayRecord?.Id, null, cancellationToken));
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
        List<PhysicalRoom> rooms)
    {
        return rooms.Count == requestedRoomIds.Count &&
            rooms.All(room => room.HotelId == hotelId &&
                room.RoomTypeId == roomTypeId &&
                requestedRoomIds.Contains(room.Id) &&
                room.Status == RoomOperationalStatus.Available);
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
            where assignment.BookingId == bookingId
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
