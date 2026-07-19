using System.Data;
using HotelMarketplace.Application.Payments;
using HotelMarketplace.Application.Payments.Dtos;
using HotelMarketplace.Application.Payments.Requests;
using HotelMarketplace.Domain.Entities;
using HotelMarketplace.Domain.Enums;
using HotelMarketplace.Infrastructure.Persistence.Common;
using HotelMarketplace.SharedKernel.Time;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;

namespace HotelMarketplace.Infrastructure.Persistence.Payments;

internal sealed class EfPaymentRepository : IPaymentRepository
{
    private const string DemoProvider = "DEMO";
    private readonly HotelMarketplaceDbContext _dbContext;
    private readonly IDateTimeProvider _dateTimeProvider;

    public EfPaymentRepository(
        HotelMarketplaceDbContext dbContext,
        IDateTimeProvider dateTimeProvider)
    {
        _dbContext = dbContext;
        _dateTimeProvider = dateTimeProvider;
    }

    public async Task<DemoPaymentPersistenceResult> ConfirmDemoPaymentAsync(
        Guid bookingId,
        Guid currentUserId,
        ConfirmDemoPaymentRequest request,
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
                return DemoPaymentPersistenceResult.Failure(
                    DemoPaymentPersistenceStatus.LockUnavailable,
                    "Demo payment booking lock was not available.");
            }

            Booking? booking = await _dbContext.Bookings
                .IgnoreQueryFilters()
                .FirstOrDefaultAsync(entity => entity.Id == bookingId, cancellationToken);

            if (booking is null)
            {
                await transaction.RollbackAsync(cancellationToken);
                return DemoPaymentPersistenceResult.Failure(
                    DemoPaymentPersistenceStatus.BookingNotFound,
                    "Booking was not found.");
            }

            if (booking.CustomerUserAccountId != currentUserId)
            {
                await transaction.RollbackAsync(cancellationToken);
                return DemoPaymentPersistenceResult.Failure(
                    DemoPaymentPersistenceStatus.Forbidden,
                    "Current user cannot confirm this booking.");
            }

            if (booking.PaymentMode != PaymentMode.PlatformCollect)
            {
                await transaction.RollbackAsync(cancellationToken);
                return DemoPaymentPersistenceResult.Failure(
                    DemoPaymentPersistenceStatus.BookingNotPendingPayment,
                    "Booking does not use platform payment.");
            }

            if (request.Amount != booking.TotalAmount)
            {
                await transaction.RollbackAsync(cancellationToken);
                return DemoPaymentPersistenceResult.Failure(
                    DemoPaymentPersistenceStatus.AmountMismatch,
                    "Demo payment amount does not match booking total.");
            }

            PaymentTransaction? paymentTransaction = await _dbContext.PaymentTransactions
                .IgnoreQueryFilters()
                .Where(payment => payment.BookingId == booking.Id && payment.Provider == DemoProvider)
                .OrderByDescending(payment => payment.CreatedAtUtc)
                .FirstOrDefaultAsync(cancellationToken);

            if (booking.Status == BookingStatus.Confirmed &&
                paymentTransaction?.Status == PaymentStatus.Paid &&
                paymentTransaction.PaidAtUtc.HasValue)
            {
                await transaction.CommitAsync(cancellationToken);
                return DemoPaymentPersistenceResult.Duplicate(ToResult(
                    paymentTransaction,
                    "duplicate"));
            }

            if (booking.Status != BookingStatus.PendingPayment)
            {
                await transaction.RollbackAsync(cancellationToken);
                return DemoPaymentPersistenceResult.Failure(
                    DemoPaymentPersistenceStatus.BookingNotPendingPayment,
                    "Booking is not waiting for demo payment.");
            }

            DateTime utcNow = _dateTimeProvider.UtcNow;
            if (booking.PaymentExpiresAtUtc is null || booking.PaymentExpiresAtUtc <= utcNow)
            {
                booking.ExpirePaymentHold(utcNow);
                if (paymentTransaction is not null)
                {
                    paymentTransaction.MarkFailed();
                }

                await _dbContext.SaveChangesAsync(cancellationToken);
                await transaction.CommitAsync(cancellationToken);
                return DemoPaymentPersistenceResult.Failure(
                    DemoPaymentPersistenceStatus.PaymentExpired,
                    "Payment hold has expired.");
            }

            string paymentReference;
            if (paymentTransaction is null ||
                paymentTransaction.Status is PaymentStatus.Failed or PaymentStatus.Cancelled)
            {
                Guid paymentTransactionId = Guid.NewGuid();
                paymentReference = $"DEMO-{paymentTransactionId:N}";
                paymentTransaction = new PaymentTransaction(
                    paymentTransactionId,
                    booking.HotelId,
                    booking.Id,
                    DemoProvider,
                    booking.TotalAmount);
                paymentTransaction.ReserveGatewayReference(paymentReference);
                await _dbContext.PaymentTransactions.AddAsync(paymentTransaction, cancellationToken);
            }
            else
            {
                paymentReference = paymentTransaction.GatewayReference ?? $"DEMO-{paymentTransaction.Id:N}";
                if (paymentTransaction.GatewayReference is null)
                {
                    paymentTransaction.ReserveGatewayReference(paymentReference);
                }
            }

            paymentTransaction.MarkPaid(paymentReference, utcNow);
            booking.ConfirmPayment();

            await EnsureCommissionRecordAsync(booking, cancellationToken);
            await _dbContext.AuditRecords.AddAsync(
                new AuditRecord(
                    Guid.NewGuid(),
                    currentUserId,
                    "ConfirmDemoPayment",
                    nameof(PaymentTransaction),
                    paymentTransaction.Id,
                    $"DEMO payment confirmed booking {booking.BookingCode} for {booking.TotalAmount:0.00}.",
                    booking.HotelId),
                cancellationToken);
            await _dbContext.NotificationRecords.AddAsync(
                new NotificationRecord(
                    Guid.NewGuid(),
                    currentUserId,
                    "DemoPaymentConfirmed",
                    nameof(Booking),
                    booking.Id,
                    $"Demo payment confirmed booking {booking.BookingCode}.",
                    booking.HotelId),
                cancellationToken);

            await _dbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);

            return DemoPaymentPersistenceResult.Processed(ToResult(paymentTransaction, "processed"));
        });
    }

    private async Task EnsureCommissionRecordAsync(
        Booking booking,
        CancellationToken cancellationToken)
    {
        bool commissionExists = await _dbContext.CommissionRecords
            .IgnoreQueryFilters()
            .AnyAsync(commission => commission.BookingId == booking.Id, cancellationToken);

        if (commissionExists)
        {
            return;
        }

        decimal commissionRate = await _dbContext.HotelProperties
            .IgnoreQueryFilters()
            .Where(hotel => hotel.Id == booking.HotelId)
            .Select(hotel => hotel.DefaultCommissionRate)
            .FirstAsync(cancellationToken);

        await _dbContext.CommissionRecords.AddAsync(
            new CommissionRecord(
                Guid.NewGuid(),
                booking.HotelId,
                booking.Id,
                booking.TotalAmount,
                commissionRate),
            cancellationToken);
    }

    private static DemoPaymentResultDto ToResult(
        PaymentTransaction paymentTransaction,
        string status)
    {
        return new DemoPaymentResultDto(
            status,
            status == "duplicate"
                ? "Demo payment was already confirmed."
                : "Demo payment confirmed the booking.",
            paymentTransaction.Id,
            paymentTransaction.Provider,
            paymentTransaction.Amount,
            paymentTransaction.PaidAtUtc!.Value);
    }
}
