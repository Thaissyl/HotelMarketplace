using System.Data;
using System.Globalization;
using HotelMarketplace.Application.Bookings;
using HotelMarketplace.Application.Bookings.Dtos;
using HotelMarketplace.Application.Inventory;
using HotelMarketplace.Domain.Entities;
using HotelMarketplace.Domain.Enums;
using HotelMarketplace.Infrastructure.Persistence.Common;
using HotelMarketplace.SharedKernel.Time;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;

namespace HotelMarketplace.Infrastructure.Persistence.Bookings;

internal sealed class EfBookingRepository : IBookingRepository
{
    private readonly HotelMarketplaceDbContext _dbContext;
    private readonly IDateTimeProvider _dateTimeProvider;
    private readonly IInventoryCommitmentCoordinator _inventoryCommitmentCoordinator;

    public EfBookingRepository(
        HotelMarketplaceDbContext dbContext,
        IDateTimeProvider dateTimeProvider,
        IInventoryCommitmentCoordinator inventoryCommitmentCoordinator)
    {
        _dbContext = dbContext;
        _dateTimeProvider = dateTimeProvider;
        _inventoryCommitmentCoordinator = inventoryCommitmentCoordinator;
    }

    public async Task<CreateBookingRepositoryResult> CreatePendingBookingAsync(
        CreateBookingRepositoryRequest request,
        CancellationToken cancellationToken)
    {
        Microsoft.EntityFrameworkCore.Storage.IExecutionStrategy executionStrategy = _dbContext.Database.CreateExecutionStrategy();

        return await executionStrategy.ExecuteAsync(async () =>
        {
            await using IDbContextTransaction transaction = await _dbContext.Database.BeginTransactionAsync(
                IsolationLevel.Serializable,
                cancellationToken);

            DateTime utcNow = _dateTimeProvider.UtcNow;
            DateTime? paymentExpiresAtUtc = request.PaymentMode == PaymentMode.PlatformCollect
                ? utcNow.AddMinutes(15)
                : null;

            bool hotelIsBookable = await _dbContext.HotelProperties
                .IgnoreQueryFilters()
                .AsNoTracking()
                .AnyAsync(hotel => hotel.Id == request.HotelId &&
                    hotel.ApprovalStatus == HotelApprovalStatus.Approved &&
                    hotel.PublicationStatus == PublicationStatus.Published,
                    cancellationToken);

            if (!hotelIsBookable)
            {
                await transaction.RollbackAsync(cancellationToken);
                return CreateBookingRepositoryResult.Failure(CreateBookingRepositoryStatus.HotelNotAvailable);
            }

            RoomTypeBookingReadModel? roomType = await _dbContext.RoomTypes
                .IgnoreQueryFilters()
                .AsNoTracking()
                .Where(roomType => roomType.Id == request.RoomTypeId &&
                    roomType.HotelId == request.HotelId &&
                    roomType.Status == RecordStatus.Active)
                .Select(roomType => new RoomTypeBookingReadModel(
                    roomType.Id,
                    roomType.HotelId,
                    roomType.AdultCapacity,
                    roomType.ChildCapacity,
                    roomType.BasePricePerNight))
                .FirstOrDefaultAsync(cancellationToken);

            if (roomType is null)
            {
                await transaction.RollbackAsync(cancellationToken);
                return CreateBookingRepositoryResult.Failure(CreateBookingRepositoryStatus.RoomTypeNotAvailable);
            }

            if ((roomType.AdultCapacity + roomType.ChildCapacity) * request.RoomCount < request.GuestCount)
            {
                await transaction.RollbackAsync(cancellationToken);
                return CreateBookingRepositoryResult.Failure(CreateBookingRepositoryStatus.CapacityExceeded);
            }

            InventoryCommitmentEvaluation inventory = await _inventoryCommitmentCoordinator.AcquireAndEvaluateAsync(
                request.HotelId,
                request.RoomTypeId,
                request.CheckInDate,
                request.CheckOutDate,
                request.RoomCount,
                utcNow,
                ignoredBookingId: null,
                cancellationToken);

            if (inventory.Status == InventoryCommitmentStatus.LockUnavailable)
            {
                await transaction.RollbackAsync(cancellationToken);
                return CreateBookingRepositoryResult.Failure(CreateBookingRepositoryStatus.ReservationLockUnavailable);
            }

            if (inventory.Status == InventoryCommitmentStatus.InsufficientAvailability)
            {
                await transaction.RollbackAsync(cancellationToken);
                return CreateBookingRepositoryResult.Failure(CreateBookingRepositoryStatus.InsufficientAvailability);
            }

            int nights = request.CheckOutDate.DayNumber - request.CheckInDate.DayNumber;
            decimal totalAmount = request.RoomCount * nights * roomType.BasePricePerNight;
            Guid bookingId = Guid.NewGuid();
            string bookingCode = GenerateBookingCode(utcNow);

            Booking booking = new(
                bookingId,
                bookingCode,
                request.CustomerUserAccountId,
                request.HotelId,
                request.CheckInDate,
                request.CheckOutDate,
                request.PaymentMode,
                BookingSource.Marketplace,
                totalAmount,
                request.GuestCount,
                request.GuestFullName,
                request.GuestPhone);

            CancellationPolicy? cancellationPolicy = await _dbContext.CancellationPolicies
                .IgnoreQueryFilters()
                .AsNoTracking()
                .FirstOrDefaultAsync(
                    policy => policy.HotelId == request.HotelId && policy.Status == RecordStatus.Active,
                    cancellationToken);
            if (cancellationPolicy is not null)
            {
                booking.ApplyCancellationPolicySnapshot(cancellationPolicy);
            }

            if (paymentExpiresAtUtc.HasValue)
            {
                booking.SetPaymentExpiration(paymentExpiresAtUtc.Value);
            }
            booking.AddRoom(new BookingRoom(
                Guid.NewGuid(),
                bookingId,
                request.RoomTypeId,
                request.RoomCount,
                roomType.BasePricePerNight,
                nights));

            await _dbContext.Bookings.AddAsync(booking, cancellationToken);
            if (request.PaymentMode == PaymentMode.PayAtProperty)
            {
                decimal commissionRate = await _dbContext.HotelProperties
                    .IgnoreQueryFilters()
                    .Where(hotel => hotel.Id == request.HotelId)
                    .Select(hotel => hotel.DefaultCommissionRate)
                    .SingleAsync(cancellationToken);
                await _dbContext.CommissionRecords.AddAsync(
                    new CommissionRecord(
                        Guid.NewGuid(),
                        request.HotelId,
                        booking.Id,
                        booking.TotalAmount,
                        commissionRate,
                        CommissionStatus.Receivable),
                    cancellationToken);
            }

            await _dbContext.AuditRecords.AddAsync(
                new AuditRecord(
                    Guid.NewGuid(),
                    request.CustomerUserAccountId,
                    "CreateBooking",
                    nameof(Booking),
                    booking.Id,
                    $"Marketplace booking {booking.BookingCode} created with {booking.PaymentMode}.",
                    booking.HotelId),
                cancellationToken);
            await _dbContext.NotificationRecords.AddAsync(
                new NotificationRecord(
                    Guid.NewGuid(),
                    request.CustomerUserAccountId,
                    "BookingCreated",
                    nameof(Booking),
                    booking.Id,
                    request.PaymentMode == PaymentMode.PayAtProperty
                        ? $"Booking {booking.BookingCode} is confirmed. Payment is due at the property."
                        : $"Booking {booking.BookingCode} is awaiting demo payment.",
                    booking.HotelId),
                cancellationToken);
            await _dbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);

            BookingDto bookingDto = new(
                booking.Id,
                booking.BookingCode,
                booking.HotelId,
                request.RoomTypeId,
                booking.CheckInDate,
                booking.CheckOutDate,
                request.RoomCount,
                request.GuestCount,
                nights,
                roomType.BasePricePerNight,
                booking.TotalAmount,
                booking.PaymentMode,
                booking.Status,
                booking.CreatedAtUtc,
                booking.PaymentExpiresAtUtc,
                booking.GuestFullName,
                booking.GuestPhone);

            return CreateBookingRepositoryResult.Success(bookingDto);
        });
    }

    public async Task<IReadOnlyCollection<BookingDto>> GetBookingsForCustomerAsync(
        Guid customerUserAccountId,
        CancellationToken cancellationToken)
    {
        List<BookingReadModel> rows = await (
            from booking in _dbContext.Bookings.IgnoreQueryFilters().AsNoTracking()
            join bookingRoom in _dbContext.BookingRooms.IgnoreQueryFilters().AsNoTracking()
                on booking.Id equals bookingRoom.BookingId
            join hotel in _dbContext.HotelProperties.IgnoreQueryFilters().AsNoTracking()
                on booking.HotelId equals hotel.Id
            join roomType in _dbContext.RoomTypes.IgnoreQueryFilters().AsNoTracking()
                on bookingRoom.RoomTypeId equals roomType.Id
            join refund in _dbContext.RefundRecords.IgnoreQueryFilters().AsNoTracking()
                on booking.Id equals refund.BookingId into refunds
            from refund in refunds.DefaultIfEmpty()
            where booking.CustomerUserAccountId == customerUserAccountId
            orderby booking.CreatedAtUtc descending
            select new BookingReadModel(
                booking.Id,
                booking.BookingCode,
                booking.HotelId,
                bookingRoom.RoomTypeId,
                booking.CheckInDate,
                booking.CheckOutDate,
                booking.GuestCount,
                bookingRoom.Quantity,
                bookingRoom.Nights,
                bookingRoom.UnitPricePerNight,
                booking.TotalAmount,
                booking.PaymentMode,
                booking.Status,
                booking.CreatedAtUtc,
                booking.PaymentExpiresAtUtc,
                booking.GuestFullName,
                booking.GuestPhone,
                refund == null ? null : refund.Status,
                refund == null ? null : refund.RequestedAmount,
                hotel.Name,
                roomType.Name,
                refund == null ? null : refund.ApprovedAmount))
            .ToListAsync(cancellationToken);

        return rows
            .Select(row => new BookingDto(
                row.Id,
                row.BookingCode,
                row.HotelId,
                row.RoomTypeId,
                row.CheckInDate,
                row.CheckOutDate,
                row.RoomCount,
                row.GuestCount,
                row.Nights,
                row.UnitPricePerNight,
                row.TotalAmount,
                row.PaymentMode,
                row.Status,
                row.CreatedAtUtc,
                row.PaymentExpiresAtUtc,
                row.GuestFullName,
                row.GuestPhone,
                row.RefundStatus,
                row.RefundRequestedAmount,
                row.HotelName,
                row.RoomTypeName,
                row.RefundApprovedAmount))
            .ToArray();
    }

    public async Task<BookingCancellationQuotePersistenceResult> GetCancellationQuoteAsync(
        Guid bookingId,
        Guid customerUserAccountId,
        CancellationToken cancellationToken)
    {
        CancellationBookingReadModel? booking = await GetCancellationBookingAsync(
            bookingId,
            cancellationToken);

        if (booking is null)
        {
            return BookingCancellationQuotePersistenceResult.Failure(
                BookingCancellationPersistenceStatus.BookingNotFound);
        }

        if (booking.CustomerUserAccountId != customerUserAccountId)
        {
            return BookingCancellationQuotePersistenceResult.Failure(
                BookingCancellationPersistenceStatus.Forbidden);
        }

        CancellationPolicyReadModel? policy = await GetApplicableCancellationPolicyAsync(booking, cancellationToken);
        bool isPaid = await IsBookingPaidAsync(booking.Id, cancellationToken);

        return BookingCancellationQuotePersistenceResult.Success(
            BuildCancellationQuote(booking, policy, isPaid, _dateTimeProvider.UtcNow));
    }

    public async Task<BookingCancellationPersistenceResult> CancelBookingAsync(
        Guid bookingId,
        Guid customerUserAccountId,
        string reason,
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
                return BookingCancellationPersistenceResult.Failure(
                    BookingCancellationPersistenceStatus.LockUnavailable);
            }

            Booking? booking = await _dbContext.Bookings
                .IgnoreQueryFilters()
                .Include(entity => entity.Rooms)
                .FirstOrDefaultAsync(entity => entity.Id == bookingId, cancellationToken);

            if (booking is null)
            {
                await transaction.RollbackAsync(cancellationToken);
                return BookingCancellationPersistenceResult.Failure(
                    BookingCancellationPersistenceStatus.BookingNotFound);
            }

            if (booking.CustomerUserAccountId != customerUserAccountId)
            {
                await transaction.RollbackAsync(cancellationToken);
                return BookingCancellationPersistenceResult.Failure(
                    BookingCancellationPersistenceStatus.Forbidden);
            }

            if (booking.Status is not (BookingStatus.PendingPayment or BookingStatus.Confirmed))
            {
                await transaction.RollbackAsync(cancellationToken);
                return BookingCancellationPersistenceResult.Failure(
                    BookingCancellationPersistenceStatus.InvalidBookingStatus);
            }

            bool inventoryLocksAcquired = await _inventoryCommitmentCoordinator.AcquireRoomTypeLocksAsync(
                booking.Rooms.Select(room => new InventoryRoomTypeKey(booking.HotelId, room.RoomTypeId)),
                cancellationToken);
            if (!inventoryLocksAcquired)
            {
                await transaction.RollbackAsync(cancellationToken);
                return BookingCancellationPersistenceResult.Failure(
                    BookingCancellationPersistenceStatus.LockUnavailable);
            }

            List<BookingRoomAssignment> assignments = await _dbContext.BookingRoomAssignments
                .IgnoreQueryFilters()
                .Where(assignment => assignment.BookingId == booking.Id && assignment.Status == RecordStatus.Active)
                .ToListAsync(cancellationToken);
            List<Guid> assignedRoomIds = assignments.Select(assignment => assignment.PhysicalRoomId).ToList();

            if (!await SqlApplicationLock.AcquireRoomLocksAsync(
                    _dbContext,
                    booking.HotelId,
                    assignedRoomIds,
                    cancellationToken))
            {
                await transaction.RollbackAsync(cancellationToken);
                return BookingCancellationPersistenceResult.Failure(
                    BookingCancellationPersistenceStatus.LockUnavailable);
            }

            List<PhysicalRoom> assignedRooms = await _dbContext.PhysicalRooms
                .IgnoreQueryFilters()
                .Where(room => assignedRoomIds.Contains(room.Id))
                .ToListAsync(cancellationToken);

            DateTime utcNow = _dateTimeProvider.UtcNow;
            CancellationBookingReadModel cancellationReadModel = ToCancellationReadModel(booking);
            CancellationPolicyReadModel? policy = await GetApplicableCancellationPolicyAsync(
                cancellationReadModel,
                cancellationToken);
            bool isPaid = await IsBookingPaidAsync(booking.Id, cancellationToken);
            BookingCancellationQuoteDto quote = BuildCancellationQuote(
                cancellationReadModel,
                policy,
                isPaid,
                utcNow);

            booking.Cancel(reason, utcNow);

            PaymentTransaction[] openPayments = await _dbContext.PaymentTransactions
                .IgnoreQueryFilters()
                .Where(payment => payment.BookingId == booking.Id &&
                    (payment.Status == PaymentStatus.Pending || payment.Status == PaymentStatus.Processing))
                .ToArrayAsync(cancellationToken);
            foreach (PaymentTransaction payment in openPayments)
            {
                payment.MarkFailed();
            }

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
                        booking.HotelId,
                        room.Id,
                        previousStatus,
                        room.Status,
                        customerUserAccountId),
                    cancellationToken);
            }

            RefundRecord? refund = null;
            if (quote.EstimatedRefundAmount > 0)
            {
                refund = new RefundRecord(
                    Guid.NewGuid(),
                    booking.HotelId,
                    booking.Id,
                    quote.EstimatedRefundAmount,
                    $"Customer cancellation: {reason.Trim()}");
                await _dbContext.RefundRecords.AddAsync(refund, cancellationToken);
            }

            await _dbContext.AuditRecords.AddAsync(
                new AuditRecord(
                    Guid.NewGuid(),
                    customerUserAccountId,
                    "CancelBooking",
                    nameof(Booking),
                    booking.Id,
                    $"Customer cancelled booking {booking.BookingCode}. Refund requested: {quote.EstimatedRefundAmount:0.00}.",
                    booking.HotelId),
                cancellationToken);
            await _dbContext.NotificationRecords.AddAsync(
                new NotificationRecord(
                    Guid.NewGuid(),
                    customerUserAccountId,
                    "BookingCancelled",
                    nameof(Booking),
                    booking.Id,
                    refund is null
                        ? $"Booking {booking.BookingCode} was cancelled. No refund is due under the applicable policy."
                        : $"Booking {booking.BookingCode} was cancelled. A refund request for {refund.RequestedAmount:0.00} is pending review.",
                    booking.HotelId),
                cancellationToken);

            await _dbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);

            return BookingCancellationPersistenceResult.Success(
                new BookingCancellationResultDto(
                    booking.Id,
                    booking.Status,
                    booking.CancelledAtUtc!.Value,
                    booking.CancellationReason!,
                    refund?.RequestedAmount ?? 0,
                    refund?.Id,
                    refund?.Status,
                    refund is null
                        ? "Booking cancelled. No refund is due under the applicable policy."
                        : "Booking cancelled. The refund request is pending administrator review."));
        });
    }

    private async Task<CancellationBookingReadModel?> GetCancellationBookingAsync(
        Guid bookingId,
        CancellationToken cancellationToken)
    {
        return await _dbContext.Bookings
            .IgnoreQueryFilters()
            .AsNoTracking()
            .Where(booking => booking.Id == bookingId)
            .Select(booking => new CancellationBookingReadModel(
                booking.Id,
                booking.CustomerUserAccountId,
                booking.HotelId,
                booking.Status,
                booking.PaymentMode,
                booking.CheckInDate,
                booking.TotalAmount,
                booking.CancellationPolicyName,
                booking.CancellationPolicyFreeCancellationHours,
                booking.CancellationPolicyRefundPercentage))
            .FirstOrDefaultAsync(cancellationToken);
    }

    private async Task<CancellationPolicyReadModel?> GetCancellationPolicyAsync(
        Guid hotelId,
        CancellationToken cancellationToken)
    {
        return await _dbContext.CancellationPolicies
            .IgnoreQueryFilters()
            .AsNoTracking()
            .Where(policy => policy.HotelId == hotelId && policy.Status == RecordStatus.Active)
            .OrderBy(policy => policy.Id)
            .Select(policy => new CancellationPolicyReadModel(
                policy.Name,
                policy.FreeCancellationHours,
                policy.RefundPercentage))
            .FirstOrDefaultAsync(cancellationToken);
    }

    private async Task<CancellationPolicyReadModel?> GetApplicableCancellationPolicyAsync(
        CancellationBookingReadModel booking,
        CancellationToken cancellationToken)
    {
        if (booking.CancellationPolicyName is not null &&
            booking.CancellationPolicyFreeCancellationHours.HasValue &&
            booking.CancellationPolicyRefundPercentage.HasValue)
        {
            return new CancellationPolicyReadModel(
                booking.CancellationPolicyName,
                booking.CancellationPolicyFreeCancellationHours.Value,
                booking.CancellationPolicyRefundPercentage.Value);
        }

        return await GetCancellationPolicyAsync(booking.HotelId, cancellationToken);
    }

    private static CancellationBookingReadModel ToCancellationReadModel(Booking booking) =>
        new(
            booking.Id,
            booking.CustomerUserAccountId,
            booking.HotelId,
            booking.Status,
            booking.PaymentMode,
            booking.CheckInDate,
            booking.TotalAmount,
            booking.CancellationPolicyName,
            booking.CancellationPolicyFreeCancellationHours,
            booking.CancellationPolicyRefundPercentage);

    private async Task<bool> IsBookingPaidAsync(Guid bookingId, CancellationToken cancellationToken)
    {
        return await _dbContext.PaymentTransactions
            .IgnoreQueryFilters()
            .AsNoTracking()
            .AnyAsync(payment => payment.BookingId == bookingId && payment.Status == PaymentStatus.Paid, cancellationToken);
    }

    private static BookingCancellationQuoteDto BuildCancellationQuote(
        CancellationBookingReadModel booking,
        CancellationPolicyReadModel? policy,
        bool isPaid,
        DateTime utcNow)
    {
        bool canCancel = booking.Status is BookingStatus.PendingPayment or BookingStatus.Confirmed;
        DateTime? deadlineUtc = policy is null
            ? null
            : booking.CheckInDate.ToDateTime(TimeOnly.MinValue, DateTimeKind.Utc)
                .AddHours(-policy.FreeCancellationHours);
        bool isWithinWindow = deadlineUtc.HasValue && utcNow <= deadlineUtc.Value;
        decimal refundPercentage = policy?.RefundPercentage ?? 0;
        decimal refundAmount = canCancel &&
            booking.PaymentMode == PaymentMode.PlatformCollect &&
            isPaid &&
            isWithinWindow
                ? decimal.Round(
                    booking.TotalAmount * refundPercentage / 100m,
                    2,
                    MidpointRounding.AwayFromZero)
                : 0;

        string summary = !canCancel
            ? "This booking can no longer be cancelled."
            : !isPaid
                ? "The booking can be cancelled and no refund is required because no payment was collected."
                : refundAmount > 0
                    ? $"Cancellation now is eligible for an estimated refund of {refundAmount:0.00}."
                    : "The booking can be cancelled, but it is outside the refundable policy window.";

        return new BookingCancellationQuoteDto(
            booking.Id,
            booking.Status,
            booking.PaymentMode,
            canCancel,
            isPaid,
            policy?.Name,
            policy?.FreeCancellationHours,
            refundPercentage,
            deadlineUtc,
            isWithinWindow,
            refundAmount,
            summary);
    }

    private static string GenerateBookingCode(DateTime utcNow)
    {
        string suffix = Guid.NewGuid().ToString("N", CultureInfo.InvariantCulture)[..10].ToUpperInvariant();
        return $"BK{utcNow.ToString("yyyyMMddHHmmss", CultureInfo.InvariantCulture)}{suffix}";
    }

    private sealed record RoomTypeBookingReadModel(
        Guid Id,
        Guid HotelId,
        int AdultCapacity,
        int ChildCapacity,
        decimal BasePricePerNight);

    private sealed record BookingReadModel(
        Guid Id,
        string BookingCode,
        Guid HotelId,
        Guid RoomTypeId,
        DateOnly CheckInDate,
        DateOnly CheckOutDate,
        int GuestCount,
        int RoomCount,
        int Nights,
        decimal UnitPricePerNight,
        decimal TotalAmount,
        PaymentMode PaymentMode,
        BookingStatus Status,
        DateTime CreatedAtUtc,
        DateTime? PaymentExpiresAtUtc,
        string GuestFullName,
        string GuestPhone,
        RefundStatus? RefundStatus,
        decimal? RefundRequestedAmount,
        string HotelName,
        string RoomTypeName,
        decimal? RefundApprovedAmount);

    private sealed record CancellationBookingReadModel(
        Guid Id,
        Guid CustomerUserAccountId,
        Guid HotelId,
        BookingStatus Status,
        PaymentMode PaymentMode,
        DateOnly CheckInDate,
        decimal TotalAmount,
        string? CancellationPolicyName,
        int? CancellationPolicyFreeCancellationHours,
        decimal? CancellationPolicyRefundPercentage);

    private sealed record CancellationPolicyReadModel(
        string Name,
        int FreeCancellationHours,
        decimal RefundPercentage);
}
