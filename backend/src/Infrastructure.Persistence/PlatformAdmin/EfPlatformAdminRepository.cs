using System.Data;
using System.Data.Common;
using System.Globalization;
using HotelMarketplace.Application.PlatformAdmin;
using HotelMarketplace.Application.PlatformAdmin.Dtos;
using HotelMarketplace.Application.PlatformAdmin.Requests;
using HotelMarketplace.Domain.Entities;
using HotelMarketplace.Domain.Enums;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;

namespace HotelMarketplace.Infrastructure.Persistence.PlatformAdmin;

internal sealed class EfPlatformAdminRepository : IPlatformAdminRepository
{
    private static readonly BookingStatus[] SuccessfulBookingStatuses =
    {
        BookingStatus.Confirmed,
        BookingStatus.CheckedIn,
        BookingStatus.CheckedOut
    };

    private readonly HotelMarketplaceDbContext _dbContext;

    public EfPlatformAdminRepository(HotelMarketplaceDbContext dbContext)
    {
        _dbContext = dbContext;
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

        return await (
            from booking in bookingQuery
            join hotel in _dbContext.HotelProperties.IgnoreQueryFilters().AsNoTracking()
                on booking.HotelId equals hotel.Id
            join commission in _dbContext.CommissionRecords.IgnoreQueryFilters().AsNoTracking()
                on booking.Id equals commission.BookingId into commissionGroup
            from commission in commissionGroup.DefaultIfEmpty()
            group new { booking, hotel, commission } by new { booking.HotelId, hotel.Name } into hotelGroup
            orderby hotelGroup.Key.Name
            select new AdminFinanceSummaryDto(
                hotelGroup.Key.HotelId,
                hotelGroup.Key.Name,
                hotelGroup.Sum(row => row.booking.TotalAmount),
                hotelGroup.Sum(row => row.commission == null ? 0m : row.commission.CommissionAmount),
                hotelGroup.Sum(row => row.booking.TotalAmount) - hotelGroup.Sum(row => row.commission == null ? 0m : row.commission.CommissionAmount),
                hotelGroup.Count()))
            .ToListAsync(cancellationToken);
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
                    payment.MarkReconciled();
                }
                else if (request.Status == ReconciliationStatus.Exception)
                {
                    payment.MarkReconciliationException();
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
            string settlementType = request.PaymentMode == PaymentMode.PlatformCollect
                ? "HotelPayable"
                : "CommissionCollection";

            SettlementRecord settlement = new(Guid.NewGuid(), request.HotelId, settlementType, totalAmount);
            await _dbContext.SettlementRecords.AddAsync(settlement, cancellationToken);

            foreach (EligibleSettlementItem item in eligibleItems)
            {
                await _dbContext.SettlementItems.AddAsync(
                    new SettlementItem(
                        Guid.NewGuid(),
                        request.HotelId,
                        settlement.Id,
                        item.Amount,
                        item.BookingId,
                        item.CommissionRecordId,
                        item.PaymentTransactionId),
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
                    settlement.MarkSettled(request.AdminNote);
                    foreach (SettlementItem item in items)
                    {
                        item.MarkSettled();
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
                SuccessfulBookingStatuses.Contains(booking.Status) &&
                booking.CheckOutDate >= request.FromDate &&
                booking.CheckOutDate <= request.ToDate &&
                payment.Status == PaymentStatus.Paid &&
                payment.ReconciliationStatus != ReconciliationStatus.Exception &&
                payment.Amount - commission.CommissionAmount >= 0m &&
                !_dbContext.SettlementItems.IgnoreQueryFilters().Any(item =>
                    item.BookingId == booking.Id &&
                    item.Status != SettlementStatus.Exception)
            select new EligibleSettlementItem(
                booking.Id,
                commission.Id,
                payment.Id,
                payment.Amount - commission.CommissionAmount))
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
                SuccessfulBookingStatuses.Contains(booking.Status) &&
                booking.CheckOutDate >= request.FromDate &&
                booking.CheckOutDate <= request.ToDate &&
                commission.CommissionAmount > 0m &&
                !_dbContext.SettlementItems.IgnoreQueryFilters().Any(item =>
                    item.BookingId == booking.Id &&
                    item.Status != SettlementStatus.Exception)
            select new EligibleSettlementItem(
                booking.Id,
                commission.Id,
                null,
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
                settlement.TotalAmount,
                settlement.Status,
                settlement.AdminNote,
                settlement.CreatedAtUtc,
                items
                    .Where(item => item.SettlementRecordId == settlement.Id)
                    .Select(item => new AdminSettlementItemDto(
                        item.Id,
                        item.BookingId,
                        item.CommissionRecordId,
                        item.PaymentTransactionId,
                        item.Amount,
                        item.Status))
                    .ToList()))
            .ToList();
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
        Guid? PaymentTransactionId,
        decimal Amount);
}
