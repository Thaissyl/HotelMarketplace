using System.Data;
using System.Data.Common;
using System.Globalization;
using HotelMarketplace.Application.PlatformAdmin;
using HotelMarketplace.Application.PlatformAdmin.Dtos;
using HotelMarketplace.Application.PlatformAdmin.Requests;
using HotelMarketplace.Domain.Entities;
using HotelMarketplace.Domain.Enums;
using HotelMarketplace.SharedKernel.Time;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;

namespace HotelMarketplace.Infrastructure.Persistence.PlatformAdmin;

internal sealed class EfPlatformAdminRepository : IPlatformAdminRepository
{
    private static readonly BookingStatus[] SuccessfulBookingStatuses =
    {
        BookingStatus.Confirmed,
        BookingStatus.CheckedIn,
        BookingStatus.CheckedOut,
        BookingStatus.Cancelled,
        BookingStatus.NoShow
    };

    private readonly HotelMarketplaceDbContext _dbContext;
    private readonly IDateTimeProvider _dateTimeProvider;

    public EfPlatformAdminRepository(HotelMarketplaceDbContext dbContext, IDateTimeProvider dateTimeProvider)
    {
        _dbContext = dbContext;
        _dateTimeProvider = dateTimeProvider;
    }

    public async Task<IReadOnlyCollection<AdminUserDto>> GetUsersAsync(
        UserRoleCode? role,
        string? searchTerm,
        CancellationToken cancellationToken)
    {
        IQueryable<UserAccount> query = _dbContext.UserAccounts
            .IgnoreQueryFilters()
            .AsNoTracking()
            .Where(user => !user.IsSystemAccount);

        if (!string.IsNullOrWhiteSpace(searchTerm))
        {
            string normalizedSearchTerm = searchTerm.Trim();
            query = query.Where(user =>
                user.Email.Contains(normalizedSearchTerm) ||
                user.FullName.Contains(normalizedSearchTerm) ||
                (user.PhoneNumber != null && user.PhoneNumber.Contains(normalizedSearchTerm)));
        }

        if (role.HasValue)
        {
            string roleCode = role.Value.ToString().ToUpperInvariant();
            query = query.Where(user =>
                _dbContext.UserAccountRoles.IgnoreQueryFilters().Any(userRole =>
                    userRole.UserAccountId == user.Id &&
                    userRole.IsActive &&
                    _dbContext.UserRoles.IgnoreQueryFilters().Any(roleEntity =>
                        roleEntity.Id == userRole.RoleId &&
                        roleEntity.Code == roleCode)));
        }

        List<UserAccount> users = await query
            .OrderBy(user => user.Email)
            .Take(250)
            .ToListAsync(cancellationToken);

        if (users.Count == 0)
        {
            return Array.Empty<AdminUserDto>();
        }

        List<Guid> userIds = users.Select(user => user.Id).ToList();

        List<UserRoleProjection> roles = await (
            from userRole in _dbContext.UserAccountRoles.IgnoreQueryFilters().AsNoTracking()
            join roleEntity in _dbContext.UserRoles.IgnoreQueryFilters().AsNoTracking()
                on userRole.RoleId equals roleEntity.Id
            where userIds.Contains(userRole.UserAccountId) && userRole.IsActive
            select new UserRoleProjection(userRole.UserAccountId, roleEntity.Code))
            .ToListAsync(cancellationToken);

        List<UserHotelProjection> hotelAssignments = await _dbContext.HotelStaffAssignments
            .IgnoreQueryFilters()
            .AsNoTracking()
            .Where(assignment => userIds.Contains(assignment.UserAccountId) && assignment.IsActive)
            .Select(assignment => new UserHotelProjection(assignment.UserAccountId, assignment.HotelId))
            .Distinct()
            .ToListAsync(cancellationToken);

        return users
            .Select(user => new AdminUserDto(
                user.Id,
                user.Email,
                user.FullName,
                user.PhoneNumber,
                user.Status,
                roles
                    .Where(item => item.UserAccountId == user.Id)
                    .Select(item => Enum.TryParse(item.RoleCode, ignoreCase: true, out UserRoleCode roleCode) ? roleCode : (UserRoleCode?)null)
                    .Where(item => item.HasValue)
                    .Select(item => item!.Value)
                    .ToList(),
                hotelAssignments
                    .Where(item => item.UserAccountId == user.Id)
                    .Select(item => item.HotelId)
                    .Distinct()
                    .ToList(),
                user.CreatedAtUtc))
            .ToList();
    }

    public Task<PlatformAdminUserResult> SuspendUserAsync(
        Guid userId,
        Guid actorUserAccountId,
        CancellationToken cancellationToken)
    {
        return UpdateUserStatusAsync(
            userId,
            actorUserAccountId,
            "SuspendUser",
            "User account was suspended.",
            user => user.Suspend(),
            cancellationToken);
    }

    public Task<PlatformAdminUserResult> ReactivateUserAsync(
        Guid userId,
        Guid actorUserAccountId,
        CancellationToken cancellationToken)
    {
        return UpdateUserStatusAsync(
            userId,
            actorUserAccountId,
            "ReactivateUser",
            "User account was reactivated.",
            user => user.Reactivate(),
            cancellationToken);
    }

    public async Task<IReadOnlyCollection<AdminUserActivityDto>> GetUserActivityAsync(
        Guid userId,
        CancellationToken cancellationToken)
    {
        bool userExists = await _dbContext.UserAccounts
            .IgnoreQueryFilters()
            .AsNoTracking()
            .AnyAsync(user => user.Id == userId && !user.IsSystemAccount, cancellationToken);

        if (!userExists)
        {
            return Array.Empty<AdminUserActivityDto>();
        }

        return await (
            from audit in _dbContext.AuditRecords.IgnoreQueryFilters().AsNoTracking()
            join actor in _dbContext.UserAccounts.IgnoreQueryFilters().AsNoTracking()
                on audit.ActorUserAccountId equals (Guid?)actor.Id into actors
            from actor in actors.DefaultIfEmpty()
            where audit.TargetEntityId == userId ||
                audit.ActorUserAccountId == userId
            orderby audit.ActionTimestampUtc descending
            select new AdminUserActivityDto(
                audit.Id,
                audit.ActorUserAccountId ?? Guid.Empty,
                actor == null ? "System Scheduler" : actor.Email,
                audit.ActionType,
                audit.TargetEntityType,
                audit.TargetEntityId,
                audit.Summary,
                audit.ActionTimestampUtc))
            .Take(100)
            .ToListAsync(cancellationToken);
    }

    public async Task<IReadOnlyCollection<AdminHotelDto>> GetPendingHotelsAsync(CancellationToken cancellationToken)
    {
        return await _dbContext.HotelProperties
            .IgnoreQueryFilters()
            .AsNoTracking()
            .Where(hotel => hotel.ApprovalStatus == HotelApprovalStatus.PendingReview)
            .OrderBy(hotel => hotel.CreatedAtUtc)
            .Select(hotel => ToHotelDto(hotel))
            .ToListAsync(cancellationToken);
    }

    private async Task<PlatformAdminUserResult> UpdateUserStatusAsync(
        Guid userId,
        Guid actorUserAccountId,
        string actionType,
        string summary,
        Action<UserAccount> updateStatus,
        CancellationToken cancellationToken)
    {
        IExecutionStrategy executionStrategy = _dbContext.Database.CreateExecutionStrategy();

        return await executionStrategy.ExecuteAsync(async () =>
        {
            await using IDbContextTransaction transaction = await _dbContext.Database.BeginTransactionAsync(
                IsolationLevel.Serializable,
                cancellationToken);

            int lockResult = await AcquireLockAsync($"platform-admin:user:{userId:N}", cancellationToken);
            if (lockResult < 0)
            {
                await transaction.RollbackAsync(cancellationToken);
                return PlatformAdminUserResult.Failure(PlatformAdminPersistenceStatus.LockUnavailable);
            }

            UserAccount? user = await _dbContext.UserAccounts
                .IgnoreQueryFilters()
                .FirstOrDefaultAsync(entity => entity.Id == userId && !entity.IsSystemAccount, cancellationToken);

            if (user is null)
            {
                await transaction.RollbackAsync(cancellationToken);
                return PlatformAdminUserResult.Failure(PlatformAdminPersistenceStatus.UserNotFound);
            }

            updateStatus(user);

            await _dbContext.AuditRecords.AddAsync(
                new AuditRecord(
                    Guid.NewGuid(),
                    actorUserAccountId,
                    actionType,
                    nameof(UserAccount),
                    user.Id,
                    summary),
                cancellationToken);

            await _dbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);

            return PlatformAdminUserResult.Success((await GetUsersAsync(null, user.Email, cancellationToken)).Single());
        });
    }

    public async Task<PlatformAdminHotelResult> ApproveHotelAsync(
        Guid hotelId,
        Guid actorUserAccountId,
        CancellationToken cancellationToken)
    {
        return await ExecuteHotelReviewAsync(
            hotelId,
            actorUserAccountId,
            "ApproveHotel",
            hotel => hotel.Approve(),
            "Hotel was approved and published.",
            cancellationToken);
    }

    public async Task<PlatformAdminHotelResult> RejectHotelAsync(
        Guid hotelId,
        Guid actorUserAccountId,
        RejectHotelRequest request,
        CancellationToken cancellationToken)
    {
        return await ExecuteHotelReviewAsync(
            hotelId,
            actorUserAccountId,
            "RejectHotel",
            hotel => hotel.Reject(),
            $"Hotel was rejected. Reason: {request.Reason.Trim()}",
            cancellationToken);
    }

    public async Task<PlatformAdminHotelResult> UpdateCommissionRateAsync(
        Guid hotelId,
        Guid actorUserAccountId,
        UpdateCommissionRateRequest request,
        CancellationToken cancellationToken)
    {
        IExecutionStrategy executionStrategy = _dbContext.Database.CreateExecutionStrategy();

        return await executionStrategy.ExecuteAsync(async () =>
        {
            await using IDbContextTransaction transaction = await _dbContext.Database.BeginTransactionAsync(
                IsolationLevel.Serializable,
                cancellationToken);

            int lockResult = await AcquireLockAsync($"platform-admin:hotel:{hotelId:N}:commission", cancellationToken);
            if (lockResult < 0)
            {
                await transaction.RollbackAsync(cancellationToken);
                return PlatformAdminHotelResult.Failure(PlatformAdminPersistenceStatus.LockUnavailable);
            }

            HotelProperty? hotel = await _dbContext.HotelProperties
                .IgnoreQueryFilters()
                .FirstOrDefaultAsync(entity => entity.Id == hotelId, cancellationToken);

            if (hotel is null)
            {
                await transaction.RollbackAsync(cancellationToken);
                return PlatformAdminHotelResult.Failure(PlatformAdminPersistenceStatus.HotelNotFound);
            }

            hotel.UpdateCommissionRate(request.CommissionRate);
            await _dbContext.AuditRecords.AddAsync(
                new AuditRecord(
                    Guid.NewGuid(),
                    actorUserAccountId,
                    "UpdateCommissionRate",
                    nameof(HotelProperty),
                    hotel.Id,
                    $"Hotel commission rate updated to {request.CommissionRate.ToString("P2", CultureInfo.InvariantCulture)}.",
                    hotel.Id),
                cancellationToken);

            await _dbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);

            return PlatformAdminHotelResult.Success(ToHotelDto(hotel));
        });
    }

    public async Task<IReadOnlyCollection<AdminFinanceSummaryDto>> GetFinanceSummaryAsync(
        Guid? hotelId,
        DateOnly? fromDate,
        DateOnly? toDate,
        CancellationToken cancellationToken)
    {
        IQueryable<Booking> bookingQuery = _dbContext.Bookings
            .IgnoreQueryFilters()
            .AsNoTracking()
            .Where(booking => SuccessfulBookingStatuses.Contains(booking.Status));

        if (hotelId.HasValue)
        {
            bookingQuery = bookingQuery.Where(booking => booking.HotelId == hotelId.Value);
        }

        if (fromDate.HasValue)
        {
            bookingQuery = bookingQuery.Where(booking => booking.CheckOutDate >= fromDate.Value);
        }

        if (toDate.HasValue)
        {
            bookingQuery = bookingQuery.Where(booking => booking.CheckOutDate <= toDate.Value);
        }

        List<FinanceBookingRow> bookings = await (
            from booking in bookingQuery
            join hotel in _dbContext.HotelProperties.IgnoreQueryFilters().AsNoTracking()
                on booking.HotelId equals hotel.Id
            join commission in _dbContext.CommissionRecords.IgnoreQueryFilters().AsNoTracking()
                on booking.Id equals commission.BookingId into commissionGroup
            from commission in commissionGroup.DefaultIfEmpty()
            select new FinanceBookingRow(
                booking.Id,
                booking.HotelId,
                hotel.Name,
                booking.PaymentMode,
                commission == null ? 0m : commission.CommissionAmount))
            .ToListAsync(cancellationToken);

        if (bookings.Count == 0)
        {
            return Array.Empty<AdminFinanceSummaryDto>();
        }

        Dictionary<Guid, decimal> platformCollections = await (
            from payment in _dbContext.PaymentTransactions.IgnoreQueryFilters().AsNoTracking()
            join booking in bookingQuery on payment.BookingId equals booking.Id
            where payment.Status == PaymentStatus.Paid
            group payment by payment.BookingId into paymentGroup
            select new
            {
                BookingId = paymentGroup.Key,
                Amount = paymentGroup.Sum(payment => payment.Amount)
            })
            .ToDictionaryAsync(row => row.BookingId, row => row.Amount, cancellationToken);

        Dictionary<Guid, decimal> propertyCollections = await (
            from collection in _dbContext.PaymentCollectionRecords.IgnoreQueryFilters().AsNoTracking()
            join booking in bookingQuery on collection.BookingId equals booking.Id
            where collection.Status == PaymentCollectionStatus.Partial ||
                collection.Status == PaymentCollectionStatus.Completed
            group collection by collection.BookingId into collectionGroup
            select new
            {
                BookingId = collectionGroup.Key,
                Amount = collectionGroup.Sum(collection => collection.Amount)
            })
            .ToDictionaryAsync(row => row.BookingId, row => row.Amount, cancellationToken);

        Dictionary<Guid, decimal> processedRefunds = await (
            from refund in _dbContext.RefundRecords.IgnoreQueryFilters().AsNoTracking()
            join booking in bookingQuery on refund.BookingId equals booking.Id
            where refund.Status == RefundStatus.Processed
            group refund by refund.BookingId into refundGroup
            select new
            {
                BookingId = refundGroup.Key,
                Amount = refundGroup.Sum(refund => refund.ApprovedAmount)
            })
            .ToDictionaryAsync(row => row.BookingId, row => row.Amount, cancellationToken);

        return bookings
            .Select(booking =>
            {
                Dictionary<Guid, decimal> collectionSource = booking.PaymentMode == PaymentMode.PlatformCollect
                    ? platformCollections
                    : propertyCollections;
                collectionSource.TryGetValue(booking.BookingId, out decimal collectedAmount);
                processedRefunds.TryGetValue(booking.BookingId, out decimal refundAmount);

                return new FinanceSummaryRow(
                    booking.HotelId,
                    booking.HotelName,
                    collectedAmount - refundAmount,
                    booking.CommissionAmount);
            })
            .Where(row => row.NetRevenue > 0m)
            .GroupBy(row => new { row.HotelId, row.HotelName })
            .OrderBy(group => group.Key.HotelName)
            .Select(group => new AdminFinanceSummaryDto(
                group.Key.HotelId,
                group.Key.HotelName,
                group.Sum(row => row.NetRevenue),
                group.Sum(row => row.CommissionAmount),
                group.Sum(row => row.NetRevenue) - group.Sum(row => row.CommissionAmount),
                group.Count()))
            .ToArray();
    }

    public async Task<IReadOnlyCollection<AdminPaymentTransactionDto>> GetPaymentTransactionsAsync(
        ReconciliationStatus? reconciliationStatus,
        CancellationToken cancellationToken)
    {
        IQueryable<PaymentTransaction> query = _dbContext.PaymentTransactions
            .IgnoreQueryFilters()
            .AsNoTracking();

        if (reconciliationStatus.HasValue)
        {
            query = query.Where(payment => payment.ReconciliationStatus == reconciliationStatus.Value);
        }

        return await (
            from payment in query
            join hotel in _dbContext.HotelProperties.IgnoreQueryFilters().AsNoTracking()
                on payment.HotelId equals hotel.Id
            orderby payment.CreatedAtUtc descending
            select new AdminPaymentTransactionDto(
                payment.Id,
                payment.HotelId,
                hotel.Name,
                payment.BookingId,
                payment.Provider,
                payment.GatewayReference,
                payment.GatewayTransactionReference,
                payment.Amount,
                payment.Status,
                payment.ReconciliationStatus,
                payment.ReconciliationNote,
                payment.ReconciledAtUtc,
                payment.CreatedAtUtc,
                payment.PaidAtUtc))
            .ToListAsync(cancellationToken);
    }

    public async Task<PlatformAdminPaymentResult> UpdatePaymentReconciliationAsync(
        Guid paymentTransactionId,
        Guid actorUserAccountId,
        UpdatePaymentReconciliationRequest request,
        CancellationToken cancellationToken)
    {
        IExecutionStrategy executionStrategy = _dbContext.Database.CreateExecutionStrategy();

        return await executionStrategy.ExecuteAsync(async () =>
        {
            await using IDbContextTransaction transaction = await _dbContext.Database.BeginTransactionAsync(
                IsolationLevel.Serializable,
                cancellationToken);

            int lockResult = await AcquireLockAsync($"platform-admin:payment:{paymentTransactionId:N}", cancellationToken);
            if (lockResult < 0)
            {
                await transaction.RollbackAsync(cancellationToken);
                return PlatformAdminPaymentResult.Failure(PlatformAdminPersistenceStatus.LockUnavailable);
            }

            PaymentTransaction? payment = await _dbContext.PaymentTransactions
                .IgnoreQueryFilters()
                .FirstOrDefaultAsync(entity => entity.Id == paymentTransactionId, cancellationToken);

            if (payment is null)
            {
                await transaction.RollbackAsync(cancellationToken);
                return PlatformAdminPaymentResult.Failure(PlatformAdminPersistenceStatus.PaymentTransactionNotFound);
            }

            try
            {
                if (request.Status == ReconciliationStatus.Reconciled)
                {
                    payment.MarkReconciled(_dateTimeProvider.UtcNow, request.Note);
                }
                else if (request.Status == ReconciliationStatus.Exception)
                {
                    payment.MarkReconciliationException(request.Note!, _dateTimeProvider.UtcNow);
                }
                else
                {
                    await transaction.RollbackAsync(cancellationToken);
                    return PlatformAdminPaymentResult.Failure(PlatformAdminPersistenceStatus.InvalidReconciliationStatus);
                }
            }
            catch (SharedKernel.Exceptions.DomainException)
            {
                await transaction.RollbackAsync(cancellationToken);
                return PlatformAdminPaymentResult.Failure(PlatformAdminPersistenceStatus.InvalidReconciliationStatus);
            }

            await _dbContext.AuditRecords.AddAsync(
                new AuditRecord(
                    Guid.NewGuid(),
                    actorUserAccountId,
                    "UpdatePaymentReconciliation",
                    nameof(PaymentTransaction),
                    payment.Id,
                    $"Payment reconciliation status changed to {payment.ReconciliationStatus}.",
                    payment.HotelId),
                cancellationToken);

            await _dbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);

            return PlatformAdminPaymentResult.Success(await ToPaymentDtoAsync(payment.Id, cancellationToken));
        });
    }

    public async Task<IReadOnlyCollection<AdminSettlementDto>> GetSettlementsAsync(
        Guid? hotelId,
        SettlementStatus? status,
        CancellationToken cancellationToken)
    {
        IQueryable<SettlementRecord> query = _dbContext.SettlementRecords
            .IgnoreQueryFilters()
            .AsNoTracking();

        if (hotelId.HasValue)
        {
            query = query.Where(settlement => settlement.HotelId == hotelId.Value);
        }

        if (status.HasValue)
        {
            query = query.Where(settlement => settlement.Status == status.Value);
        }

        List<SettlementRecord> settlements = await query
            .OrderByDescending(settlement => settlement.CreatedAtUtc)
            .ToListAsync(cancellationToken);

        return await ToSettlementDtosAsync(settlements, cancellationToken);
    }

    public async Task<PlatformAdminSettlementResult> CreateSettlementAsync(
        Guid actorUserAccountId,
        CreateSettlementRequest request,
        CancellationToken cancellationToken)
    {
        IExecutionStrategy executionStrategy = _dbContext.Database.CreateExecutionStrategy();

        return await executionStrategy.ExecuteAsync(async () =>
        {
            await using IDbContextTransaction transaction = await _dbContext.Database.BeginTransactionAsync(
                IsolationLevel.Serializable,
                cancellationToken);

            int lockResult = await AcquireLockAsync($"platform-admin:settlement:{request.HotelId:N}:{request.PaymentMode}", cancellationToken);
            if (lockResult < 0)
            {
                await transaction.RollbackAsync(cancellationToken);
                return PlatformAdminSettlementResult.Failure(PlatformAdminPersistenceStatus.LockUnavailable);
            }

            bool hotelExists = await _dbContext.HotelProperties
                .IgnoreQueryFilters()
                .AnyAsync(hotel => hotel.Id == request.HotelId, cancellationToken);

            if (!hotelExists)
            {
                await transaction.RollbackAsync(cancellationToken);
                return PlatformAdminSettlementResult.Failure(PlatformAdminPersistenceStatus.HotelNotFound);
            }

            List<EligibleSettlementItem> eligibleItems = request.PaymentMode == PaymentMode.PlatformCollect
                ? await GetPlatformCollectEligibleItemsAsync(request, cancellationToken)
                : await GetPayAtPropertyEligibleItemsAsync(request, cancellationToken);

            if (eligibleItems.Count == 0)
            {
                await transaction.RollbackAsync(cancellationToken);
                return PlatformAdminSettlementResult.Failure(PlatformAdminPersistenceStatus.SettlementNotEligible);
            }

            decimal totalAmount = eligibleItems.Sum(item => item.Amount);
            SettlementType settlementType = request.PaymentMode == PaymentMode.PlatformCollect
                ? SettlementType.HotelPayable
                : SettlementType.CommissionCollection;

            SettlementRecord settlement = new(Guid.NewGuid(), request.HotelId, settlementType, totalAmount, request.AdminNote);
            await _dbContext.SettlementRecords.AddAsync(settlement, cancellationToken);

            foreach (EligibleSettlementItem item in eligibleItems)
            {
                await _dbContext.SettlementItems.AddAsync(
                    new SettlementItem(
                        Guid.NewGuid(),
                        request.HotelId,
                        settlement.Id,
                        item.BookingId,
                        item.CommissionRecordId,
                        item.PaymentMode,
                        item.BookingStatus,
                        item.GrossAmount,
                        item.RefundAmount,
                        item.CommissionAmount,
                        item.Amount,
                        item.PaymentTransactionId,
                        item.PaymentCollectionRecordId),
                    cancellationToken);
            }

            await _dbContext.AuditRecords.AddAsync(
                new AuditRecord(
                    Guid.NewGuid(),
                    actorUserAccountId,
                    "CreateSettlement",
                    nameof(SettlementRecord),
                    settlement.Id,
                    $"Settlement {settlementType} was created for {eligibleItems.Count.ToString(CultureInfo.InvariantCulture)} item(s). Note: {request.AdminNote ?? string.Empty}",
                    request.HotelId),
                cancellationToken);

            await _dbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);

            return PlatformAdminSettlementResult.Success((await ToSettlementDtosAsync(new[] { settlement }, cancellationToken)).Single());
        });
    }

    public async Task<PlatformAdminSettlementResult> UpdateSettlementStatusAsync(
        Guid settlementId,
        Guid actorUserAccountId,
        UpdateSettlementStatusRequest request,
        CancellationToken cancellationToken)
    {
        IExecutionStrategy executionStrategy = _dbContext.Database.CreateExecutionStrategy();

        return await executionStrategy.ExecuteAsync(async () =>
        {
            await using IDbContextTransaction transaction = await _dbContext.Database.BeginTransactionAsync(
                IsolationLevel.Serializable,
                cancellationToken);

            int lockResult = await AcquireLockAsync($"platform-admin:settlement:{settlementId:N}", cancellationToken);
            if (lockResult < 0)
            {
                await transaction.RollbackAsync(cancellationToken);
                return PlatformAdminSettlementResult.Failure(PlatformAdminPersistenceStatus.LockUnavailable);
            }

            SettlementRecord? settlement = await _dbContext.SettlementRecords
                .IgnoreQueryFilters()
                .FirstOrDefaultAsync(entity => entity.Id == settlementId, cancellationToken);

            if (settlement is null)
            {
                await transaction.RollbackAsync(cancellationToken);
                return PlatformAdminSettlementResult.Failure(PlatformAdminPersistenceStatus.SettlementNotFound);
            }

            List<SettlementItem> items = await _dbContext.SettlementItems
                .IgnoreQueryFilters()
                .Where(item => item.SettlementRecordId == settlement.Id)
                .ToListAsync(cancellationToken);

            try
            {
                if (request.Status == SettlementStatus.Settled)
                {
                    string normalizedReference = request.Reference!.Trim().ToUpperInvariant();
                    bool referenceExists = await _dbContext.SettlementRecords
                        .IgnoreQueryFilters()
                        .AnyAsync(record => record.Id != settlement.Id && record.Reference == normalizedReference, cancellationToken);
                    if (referenceExists)
                    {
                        await transaction.RollbackAsync(cancellationToken);
                        return PlatformAdminSettlementResult.Failure(PlatformAdminPersistenceStatus.InvalidSettlementStatus);
                    }

                    if (!await AreSettlementItemsStillEligibleAsync(settlement, items, cancellationToken))
                    {
                        await transaction.RollbackAsync(cancellationToken);
                        return PlatformAdminSettlementResult.Failure(PlatformAdminPersistenceStatus.SettlementNotEligible);
                    }

                    settlement.MarkSettled(
                        request.SettledAmount!.Value,
                        request.SettlementDateUtc!.Value,
                        request.Reference!,
                        request.AdminNote);
                    foreach (SettlementItem item in items)
                    {
                        if (settlement.SettlementType == SettlementType.HotelPayable)
                        {
                            item.MarkSettled();
                        }
                        else
                        {
                            item.MarkCollected();
                        }
                    }

                    List<Guid> commissionIds = items.Select(item => item.CommissionRecordId!.Value).ToList();
                    List<CommissionRecord> commissions = await _dbContext.CommissionRecords
                        .IgnoreQueryFilters()
                        .Where(commission => commissionIds.Contains(commission.Id))
                        .ToListAsync(cancellationToken);
                    foreach (CommissionRecord commission in commissions)
                    {
                        if (settlement.SettlementType == SettlementType.HotelPayable)
                        {
                            commission.MarkSettled();
                        }
                        else
                        {
                            commission.MarkCollected();
                        }
                    }
                }
                else if (request.Status == SettlementStatus.Exception)
                {
                    settlement.MarkException(request.AdminNote!);
                    foreach (SettlementItem item in items)
                    {
                        item.MarkException();
                    }
                }
                else
                {
                    await transaction.RollbackAsync(cancellationToken);
                    return PlatformAdminSettlementResult.Failure(PlatformAdminPersistenceStatus.InvalidSettlementStatus);
                }
            }
            catch (SharedKernel.Exceptions.DomainException)
            {
                await transaction.RollbackAsync(cancellationToken);
                return PlatformAdminSettlementResult.Failure(PlatformAdminPersistenceStatus.InvalidSettlementStatus);
            }

            await _dbContext.AuditRecords.AddAsync(
                new AuditRecord(
                    Guid.NewGuid(),
                    actorUserAccountId,
                    "UpdateSettlementStatus",
                    nameof(SettlementRecord),
                    settlement.Id,
                    $"Settlement status changed to {settlement.Status}.",
                    settlement.HotelId),
                cancellationToken);

            await _dbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);

            return PlatformAdminSettlementResult.Success((await ToSettlementDtosAsync(new[] { settlement }, cancellationToken)).Single());
        });
    }

    public async Task<IReadOnlyCollection<AdminRefundDto>> GetRefundsAsync(
        RefundStatus? status,
        CancellationToken cancellationToken)
    {
        IQueryable<RefundRecord> query = _dbContext.RefundRecords
            .IgnoreQueryFilters()
            .AsNoTracking();

        if (status.HasValue)
        {
            query = query.Where(refund => refund.Status == status.Value);
        }

        return await (
            from refund in query
            join hotel in _dbContext.HotelProperties.IgnoreQueryFilters().AsNoTracking()
                on refund.HotelId equals hotel.Id
            orderby refund.CreatedAtUtc descending
            select new AdminRefundDto(
                refund.Id,
                refund.HotelId,
                hotel.Name,
                refund.BookingId,
                refund.RequestedAmount,
                refund.ApprovedAmount,
                refund.Reason,
                refund.Status,
                refund.CreatedAtUtc))
            .ToListAsync(cancellationToken);
    }

    public async Task<PlatformAdminRefundResult> UpdateRefundStatusAsync(
        Guid refundId,
        Guid actorUserAccountId,
        UpdateRefundStatusRequest request,
        CancellationToken cancellationToken)
    {
        IExecutionStrategy executionStrategy = _dbContext.Database.CreateExecutionStrategy();

        return await executionStrategy.ExecuteAsync(async () =>
        {
            await using IDbContextTransaction transaction = await _dbContext.Database.BeginTransactionAsync(
                IsolationLevel.Serializable,
                cancellationToken);

            int lockResult = await AcquireLockAsync($"platform-admin:refund:{refundId:N}", cancellationToken);
            if (lockResult < 0)
            {
                await transaction.RollbackAsync(cancellationToken);
                return PlatformAdminRefundResult.Failure(PlatformAdminPersistenceStatus.LockUnavailable);
            }

            RefundRecord? refund = await _dbContext.RefundRecords
                .IgnoreQueryFilters()
                .FirstOrDefaultAsync(entity => entity.Id == refundId, cancellationToken);

            if (refund is null)
            {
                await transaction.RollbackAsync(cancellationToken);
                return PlatformAdminRefundResult.Failure(PlatformAdminPersistenceStatus.RefundNotFound);
            }

            try
            {
                if (request.Status == RefundStatus.Approved)
                {
                    refund.Approve(request.ApprovedAmount!.Value);
                }
                else if (request.Status == RefundStatus.Rejected)
                {
                    refund.Reject();
                }
                else if (request.Status == RefundStatus.Processed)
                {
                    refund.MarkProcessed();
                }
                else if (request.Status == RefundStatus.Failed)
                {
                    refund.MarkFailed();
                }
                else
                {
                    await transaction.RollbackAsync(cancellationToken);
                    return PlatformAdminRefundResult.Failure(PlatformAdminPersistenceStatus.InvalidRefundStatus);
                }
            }
            catch (SharedKernel.Exceptions.DomainException)
            {
                await transaction.RollbackAsync(cancellationToken);
                return PlatformAdminRefundResult.Failure(PlatformAdminPersistenceStatus.InvalidRefundStatus);
            }

            await _dbContext.AuditRecords.AddAsync(
                new AuditRecord(
                    Guid.NewGuid(),
                    actorUserAccountId,
                    "UpdateRefundStatus",
                    nameof(RefundRecord),
                    refund.Id,
                    $"Refund status changed to {refund.Status}.",
                    refund.HotelId),
                cancellationToken);

            await _dbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);

            return PlatformAdminRefundResult.Success(await ToRefundDtoAsync(refund.Id, cancellationToken));
        });
    }

    private async Task<PlatformAdminHotelResult> ExecuteHotelReviewAsync(
        Guid hotelId,
        Guid actorUserAccountId,
        string actionType,
        Action<HotelProperty> reviewAction,
        string auditSummary,
        CancellationToken cancellationToken)
    {
        IExecutionStrategy executionStrategy = _dbContext.Database.CreateExecutionStrategy();

        return await executionStrategy.ExecuteAsync(async () =>
        {
            await using IDbContextTransaction transaction = await _dbContext.Database.BeginTransactionAsync(
                IsolationLevel.Serializable,
                cancellationToken);

            int lockResult = await AcquireLockAsync($"platform-admin:hotel:{hotelId:N}:review", cancellationToken);
            if (lockResult < 0)
            {
                await transaction.RollbackAsync(cancellationToken);
                return PlatformAdminHotelResult.Failure(PlatformAdminPersistenceStatus.LockUnavailable);
            }

            HotelProperty? hotel = await _dbContext.HotelProperties
                .IgnoreQueryFilters()
                .FirstOrDefaultAsync(entity => entity.Id == hotelId, cancellationToken);

            if (hotel is null)
            {
                await transaction.RollbackAsync(cancellationToken);
                return PlatformAdminHotelResult.Failure(PlatformAdminPersistenceStatus.HotelNotFound);
            }

            try
            {
                reviewAction(hotel);
            }
            catch (SharedKernel.Exceptions.DomainException)
            {
                await transaction.RollbackAsync(cancellationToken);
                return PlatformAdminHotelResult.Failure(PlatformAdminPersistenceStatus.InvalidHotelReviewState);
            }

            await _dbContext.AuditRecords.AddAsync(
                new AuditRecord(Guid.NewGuid(), actorUserAccountId, actionType, nameof(HotelProperty), hotel.Id, auditSummary, hotel.Id),
                cancellationToken);

            await _dbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);

            return PlatformAdminHotelResult.Success(ToHotelDto(hotel));
        });
    }

    private async Task<List<EligibleSettlementItem>> GetPlatformCollectEligibleItemsAsync(
        CreateSettlementRequest request,
        CancellationToken cancellationToken)
    {
        return await (
            from booking in _dbContext.Bookings.IgnoreQueryFilters().AsNoTracking()
            join commission in _dbContext.CommissionRecords.IgnoreQueryFilters().AsNoTracking()
                on booking.Id equals commission.BookingId
            join payment in _dbContext.PaymentTransactions.IgnoreQueryFilters().AsNoTracking()
                on booking.Id equals payment.BookingId
            where booking.HotelId == request.HotelId &&
                booking.PaymentMode == PaymentMode.PlatformCollect &&
                (booking.Status == BookingStatus.CheckedOut ||
                    booking.Status == BookingStatus.Cancelled ||
                    booking.Status == BookingStatus.NoShow) &&
                booking.CheckOutDate >= request.FromDate &&
                booking.CheckOutDate <= request.ToDate &&
                payment.Status == PaymentStatus.Paid &&
                payment.ReconciliationStatus == ReconciliationStatus.Reconciled &&
                commission.Status == CommissionStatus.Deductible &&
                !_dbContext.RefundRecords.IgnoreQueryFilters().Any(refund =>
                    refund.BookingId == booking.Id &&
                    (refund.Status == RefundStatus.PendingReview ||
                        refund.Status == RefundStatus.Approved ||
                        refund.Status == RefundStatus.Failed)) &&
                payment.Amount -
                    (_dbContext.RefundRecords.IgnoreQueryFilters()
                        .Where(refund => refund.BookingId == booking.Id && refund.Status == RefundStatus.Processed)
                        .Sum(refund => (decimal?)refund.ApprovedAmount) ?? 0m) -
                    commission.CommissionAmount >= 0m &&
                !_dbContext.SettlementItems.IgnoreQueryFilters().Any(item =>
                    item.BookingId == booking.Id &&
                    item.Status != SettlementStatus.Exception)
            select new EligibleSettlementItem(
                booking.Id,
                commission.Id,
                booking.PaymentMode,
                booking.Status,
                payment.Amount,
                _dbContext.RefundRecords.IgnoreQueryFilters()
                    .Where(refund => refund.BookingId == booking.Id && refund.Status == RefundStatus.Processed)
                    .Sum(refund => (decimal?)refund.ApprovedAmount) ?? 0m,
                commission.CommissionAmount,
                payment.Id,
                null,
                payment.Amount -
                    (_dbContext.RefundRecords.IgnoreQueryFilters()
                        .Where(refund => refund.BookingId == booking.Id && refund.Status == RefundStatus.Processed)
                        .Sum(refund => (decimal?)refund.ApprovedAmount) ?? 0m) -
                    commission.CommissionAmount))
            .ToListAsync(cancellationToken);
    }

    private async Task<List<EligibleSettlementItem>> GetPayAtPropertyEligibleItemsAsync(
        CreateSettlementRequest request,
        CancellationToken cancellationToken)
    {
        return await (
            from booking in _dbContext.Bookings.IgnoreQueryFilters().AsNoTracking()
            join commission in _dbContext.CommissionRecords.IgnoreQueryFilters().AsNoTracking()
                on booking.Id equals commission.BookingId
            where booking.HotelId == request.HotelId &&
                booking.PaymentMode == PaymentMode.PayAtProperty &&
                booking.Status == BookingStatus.CheckedOut &&
                booking.CheckOutDate >= request.FromDate &&
                booking.CheckOutDate <= request.ToDate &&
                commission.Status == CommissionStatus.Receivable &&
                commission.CommissionAmount > 0m &&
                !_dbContext.RefundRecords.IgnoreQueryFilters().Any(refund =>
                    refund.BookingId == booking.Id &&
                    (refund.Status == RefundStatus.PendingReview ||
                        refund.Status == RefundStatus.Approved ||
                        refund.Status == RefundStatus.Failed)) &&
                _dbContext.PaymentCollectionRecords.IgnoreQueryFilters()
                    .Where(collection => collection.BookingId == booking.Id &&
                        (collection.Status == PaymentCollectionStatus.Partial ||
                            collection.Status == PaymentCollectionStatus.Completed))
                    .Sum(collection => (decimal?)collection.Amount) == booking.TotalAmount &&
                !_dbContext.SettlementItems.IgnoreQueryFilters().Any(item =>
                    item.BookingId == booking.Id &&
                    item.Status != SettlementStatus.Exception)
            select new EligibleSettlementItem(
                booking.Id,
                commission.Id,
                booking.PaymentMode,
                booking.Status,
                booking.TotalAmount,
                _dbContext.RefundRecords.IgnoreQueryFilters()
                    .Where(refund => refund.BookingId == booking.Id && refund.Status == RefundStatus.Processed)
                    .Sum(refund => (decimal?)refund.ApprovedAmount) ?? 0m,
                commission.CommissionAmount,
                null,
                _dbContext.PaymentCollectionRecords.IgnoreQueryFilters()
                    .Where(collection => collection.BookingId == booking.Id &&
                        (collection.Status == PaymentCollectionStatus.Partial ||
                            collection.Status == PaymentCollectionStatus.Completed))
                    .OrderByDescending(collection => collection.CollectedAtUtc)
                    .Select(collection => (Guid?)collection.Id)
                    .FirstOrDefault(),
                commission.CommissionAmount))
            .ToListAsync(cancellationToken);
    }

    private async Task<IReadOnlyCollection<AdminSettlementDto>> ToSettlementDtosAsync(
        IReadOnlyCollection<SettlementRecord> settlements,
        CancellationToken cancellationToken)
    {
        if (settlements.Count == 0)
        {
            return Array.Empty<AdminSettlementDto>();
        }

        List<Guid> settlementIds = settlements.Select(settlement => settlement.Id).ToList();
        List<Guid> hotelIds = settlements.Select(settlement => settlement.HotelId).Distinct().ToList();
        Dictionary<Guid, string> hotelNames = await _dbContext.HotelProperties
            .IgnoreQueryFilters()
            .AsNoTracking()
            .Where(hotel => hotelIds.Contains(hotel.Id))
            .ToDictionaryAsync(hotel => hotel.Id, hotel => hotel.Name, cancellationToken);

        List<SettlementItem> items = await _dbContext.SettlementItems
            .IgnoreQueryFilters()
            .AsNoTracking()
            .Where(item => settlementIds.Contains(item.SettlementRecordId))
            .ToListAsync(cancellationToken);

        return settlements
            .Select(settlement => new AdminSettlementDto(
                settlement.Id,
                settlement.HotelId,
                hotelNames.GetValueOrDefault(settlement.HotelId, string.Empty),
                settlement.SettlementType,
                settlement.ExpectedAmount,
                settlement.SettledAmount,
                settlement.Status,
                settlement.AdminNote,
                settlement.CreatedAtUtc,
                settlement.SettlementDateUtc,
                settlement.Reference,
                items
                    .Where(item => item.SettlementRecordId == settlement.Id)
                    .Select(item => new AdminSettlementItemDto(
                        item.Id,
                        item.BookingId,
                        item.CommissionRecordId,
                        item.PaymentTransactionId,
                        item.PaymentCollectionRecordId,
                        item.PaymentMode,
                        item.BookingStatus,
                        item.GrossAmount,
                        item.RefundAmount,
                        item.CommissionAmount,
                        item.Amount,
                        item.Status))
                    .ToList()))
            .ToList();
    }

    private async Task<bool> AreSettlementItemsStillEligibleAsync(
        SettlementRecord settlement,
        List<SettlementItem> items,
        CancellationToken cancellationToken)
    {
        if (items.Count == 0 || items.Any(item =>
                item.Status != SettlementStatus.Pending ||
                !item.BookingId.HasValue ||
                !item.CommissionRecordId.HasValue))
        {
            return false;
        }

        List<Guid> bookingIds = items.Select(item => item.BookingId!.Value).Distinct().ToList();
        List<Guid> commissionIds = items.Select(item => item.CommissionRecordId!.Value).Distinct().ToList();
        Dictionary<Guid, Booking> bookings = await _dbContext.Bookings
            .IgnoreQueryFilters()
            .AsNoTracking()
            .Where(booking => bookingIds.Contains(booking.Id))
            .ToDictionaryAsync(booking => booking.Id, cancellationToken);
        Dictionary<Guid, CommissionRecord> commissions = await _dbContext.CommissionRecords
            .IgnoreQueryFilters()
            .AsNoTracking()
            .Where(commission => commissionIds.Contains(commission.Id))
            .ToDictionaryAsync(commission => commission.Id, cancellationToken);

        if (bookings.Count != bookingIds.Count || commissions.Count != commissionIds.Count)
        {
            return false;
        }

        HashSet<Guid> unresolvedRefundBookings = (await _dbContext.RefundRecords
                .IgnoreQueryFilters()
                .AsNoTracking()
                .Where(refund => bookingIds.Contains(refund.BookingId) &&
                    (refund.Status == RefundStatus.PendingReview ||
                        refund.Status == RefundStatus.Approved ||
                        refund.Status == RefundStatus.Failed))
                .Select(refund => refund.BookingId)
                .ToListAsync(cancellationToken))
            .ToHashSet();
        Dictionary<Guid, decimal> processedRefundTotals = await _dbContext.RefundRecords
            .IgnoreQueryFilters()
            .AsNoTracking()
            .Where(refund => bookingIds.Contains(refund.BookingId) && refund.Status == RefundStatus.Processed)
            .GroupBy(refund => refund.BookingId)
            .ToDictionaryAsync(
                group => group.Key,
                group => group.Sum(refund => refund.ApprovedAmount),
                cancellationToken);

        if (settlement.SettlementType == SettlementType.HotelPayable)
        {
            List<Guid> paymentIds = items
                .Where(item => item.PaymentTransactionId.HasValue)
                .Select(item => item.PaymentTransactionId!.Value)
                .Distinct()
                .ToList();
            Dictionary<Guid, PaymentTransaction> payments = await _dbContext.PaymentTransactions
                .IgnoreQueryFilters()
                .AsNoTracking()
                .Where(payment => paymentIds.Contains(payment.Id))
                .ToDictionaryAsync(payment => payment.Id, cancellationToken);
            return paymentIds.Count == items.Count &&
                payments.Count == paymentIds.Count &&
                items.All(item =>
                {
                    Booking booking = bookings[item.BookingId!.Value];
                    CommissionRecord commission = commissions[item.CommissionRecordId!.Value];
                    PaymentTransaction payment = payments[item.PaymentTransactionId!.Value];
                    return booking.PaymentMode == PaymentMode.PlatformCollect &&
                        booking.Status == item.BookingStatus &&
                        booking.Status is BookingStatus.CheckedOut or BookingStatus.Cancelled or BookingStatus.NoShow &&
                        commission.Status == CommissionStatus.Deductible &&
                        commission.CommissionAmount == item.CommissionAmount &&
                        payment.Status == PaymentStatus.Paid &&
                        payment.ReconciliationStatus == ReconciliationStatus.Reconciled &&
                        payment.Amount == item.GrossAmount &&
                        processedRefundTotals.GetValueOrDefault(booking.Id) == item.RefundAmount &&
                        item.Amount == item.GrossAmount - item.RefundAmount - item.CommissionAmount &&
                        !unresolvedRefundBookings.Contains(booking.Id);
                });
        }

        Dictionary<Guid, decimal> collectionTotals = await _dbContext.PaymentCollectionRecords
            .IgnoreQueryFilters()
            .AsNoTracking()
            .Where(collection => bookingIds.Contains(collection.BookingId) &&
                (collection.Status == PaymentCollectionStatus.Partial ||
                    collection.Status == PaymentCollectionStatus.Completed))
            .GroupBy(collection => collection.BookingId)
            .ToDictionaryAsync(
                group => group.Key,
                group => group.Sum(collection => collection.Amount),
                cancellationToken);

        return items.All(item =>
        {
            Booking booking = bookings[item.BookingId!.Value];
            CommissionRecord commission = commissions[item.CommissionRecordId!.Value];
            return booking.PaymentMode == PaymentMode.PayAtProperty &&
                booking.Status == BookingStatus.CheckedOut &&
                commission.Status == CommissionStatus.Receivable &&
                commission.CommissionAmount == item.CommissionAmount &&
                booking.TotalAmount == item.GrossAmount &&
                processedRefundTotals.GetValueOrDefault(booking.Id) == item.RefundAmount &&
                item.Amount == item.CommissionAmount &&
                collectionTotals.GetValueOrDefault(booking.Id) == booking.TotalAmount &&
                !unresolvedRefundBookings.Contains(booking.Id);
        });
    }

    private async Task<AdminPaymentTransactionDto> ToPaymentDtoAsync(Guid paymentTransactionId, CancellationToken cancellationToken)
    {
        return await (
            from payment in _dbContext.PaymentTransactions.IgnoreQueryFilters().AsNoTracking()
            join hotel in _dbContext.HotelProperties.IgnoreQueryFilters().AsNoTracking()
                on payment.HotelId equals hotel.Id
            where payment.Id == paymentTransactionId
            select new AdminPaymentTransactionDto(
                payment.Id,
                payment.HotelId,
                hotel.Name,
                payment.BookingId,
                payment.Provider,
                payment.GatewayReference,
                payment.GatewayTransactionReference,
                payment.Amount,
                payment.Status,
                payment.ReconciliationStatus,
                payment.ReconciliationNote,
                payment.ReconciledAtUtc,
                payment.CreatedAtUtc,
                payment.PaidAtUtc))
            .FirstAsync(cancellationToken);
    }

    private async Task<AdminRefundDto> ToRefundDtoAsync(Guid refundId, CancellationToken cancellationToken)
    {
        return await (
            from refund in _dbContext.RefundRecords.IgnoreQueryFilters().AsNoTracking()
            join hotel in _dbContext.HotelProperties.IgnoreQueryFilters().AsNoTracking()
                on refund.HotelId equals hotel.Id
            where refund.Id == refundId
            select new AdminRefundDto(
                refund.Id,
                refund.HotelId,
                hotel.Name,
                refund.BookingId,
                refund.RequestedAmount,
                refund.ApprovedAmount,
                refund.Reason,
                refund.Status,
                refund.CreatedAtUtc))
            .FirstAsync(cancellationToken);
    }

    private async Task<int> AcquireLockAsync(string resource, CancellationToken cancellationToken)
    {
        DbConnection connection = _dbContext.Database.GetDbConnection();
        await using DbCommand command = connection.CreateCommand();
        command.Transaction = _dbContext.Database.CurrentTransaction?.GetDbTransaction();
        command.CommandText = """
            DECLARE @lockResult int;
            EXEC @lockResult = sys.sp_getapplock
                @Resource = @resource,
                @LockMode = 'Exclusive',
                @LockOwner = 'Transaction',
                @LockTimeout = @lockTimeout;
            SELECT @lockResult;
            """;

        DbParameter resourceParameter = command.CreateParameter();
        resourceParameter.ParameterName = "@resource";
        resourceParameter.DbType = DbType.String;
        resourceParameter.Value = resource.Length <= 255 ? resource : resource[..255];
        command.Parameters.Add(resourceParameter);

        DbParameter timeoutParameter = command.CreateParameter();
        timeoutParameter.ParameterName = "@lockTimeout";
        timeoutParameter.DbType = DbType.Int32;
        timeoutParameter.Value = 10_000;
        command.Parameters.Add(timeoutParameter);

        object? result = await command.ExecuteScalarAsync(cancellationToken);
        return Convert.ToInt32(result, CultureInfo.InvariantCulture);
    }

    private static AdminHotelDto ToHotelDto(HotelProperty hotel)
    {
        return new AdminHotelDto(
            hotel.Id,
            hotel.OwnerUserAccountId,
            hotel.Name,
            hotel.City,
            hotel.AddressLine,
            hotel.ContactEmail,
            hotel.ContactPhone,
            hotel.ApprovalStatus,
            hotel.PublicationStatus,
            hotel.DefaultCommissionRate,
            hotel.CreatedAtUtc);
    }

    private sealed record EligibleSettlementItem(
        Guid BookingId,
        Guid CommissionRecordId,
        PaymentMode PaymentMode,
        BookingStatus BookingStatus,
        decimal GrossAmount,
        decimal RefundAmount,
        decimal CommissionAmount,
        Guid? PaymentTransactionId,
        Guid? PaymentCollectionRecordId,
        decimal Amount);

    private sealed record FinanceBookingRow(
        Guid BookingId,
        Guid HotelId,
        string HotelName,
        PaymentMode PaymentMode,
        decimal CommissionAmount);

    private sealed record FinanceSummaryRow(
        Guid HotelId,
        string HotelName,
        decimal NetRevenue,
        decimal CommissionAmount);

    private sealed record UserRoleProjection(Guid UserAccountId, string RoleCode);

    private sealed record UserHotelProjection(Guid UserAccountId, Guid HotelId);
}
