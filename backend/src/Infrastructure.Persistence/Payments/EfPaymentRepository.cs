using System.Data;
using System.Globalization;
using HotelMarketplace.Application.Payments;
using HotelMarketplace.Application.Payments.Dtos;
using HotelMarketplace.Application.Payments.Models;
using HotelMarketplace.Domain.Entities;
using HotelMarketplace.Domain.Enums;
using HotelMarketplace.SharedKernel.Time;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;

namespace HotelMarketplace.Infrastructure.Persistence.Payments;

internal sealed class EfPaymentRepository : IPaymentRepository
{
    private const string Provider = "payOS";
    private const string SimulatedProvider = "Simulated";
    private readonly HotelMarketplaceDbContext _dbContext;
    private readonly IDateTimeProvider _dateTimeProvider;

    public EfPaymentRepository(
        HotelMarketplaceDbContext dbContext,
        IDateTimeProvider dateTimeProvider)
    {
        _dbContext = dbContext;
        _dateTimeProvider = dateTimeProvider;
    }

    public async Task<CreatePaymentLinkPersistenceResult> PreparePaymentLinkAsync(
        Guid bookingId,
        Guid currentUserId,
        IReadOnlyCollection<UserRoleCode> currentUserRoles,
        CancellationToken cancellationToken)
    {
        IExecutionStrategy executionStrategy = _dbContext.Database.CreateExecutionStrategy();

        return await executionStrategy.ExecuteAsync(async () =>
        {
            await using IDbContextTransaction transaction = await _dbContext.Database.BeginTransactionAsync(
                IsolationLevel.Serializable,
                cancellationToken);

            BookingPaymentReadModel? booking = await _dbContext.Bookings
                .IgnoreQueryFilters()
                .AsNoTracking()
                .Where(booking => booking.Id == bookingId)
                .Join(
                    _dbContext.UserAccounts.AsNoTracking(),
                    booking => booking.CustomerUserAccountId,
                    user => user.Id,
                    (booking, user) => new { Booking = booking, User = user })
                .Select(row => new BookingPaymentReadModel(
                    row.Booking.Id,
                    row.Booking.BookingCode,
                    row.Booking.CustomerUserAccountId,
                    row.User.Email,
                    row.Booking.HotelId,
                    row.Booking.Status,
                    row.Booking.PaymentMode,
                    row.Booking.TotalAmount,
                    row.Booking.GuestFullName,
                    row.Booking.GuestPhone,
                    row.Booking.PaymentExpiresAtUtc))
                .FirstOrDefaultAsync(cancellationToken);

            if (booking is null)
            {
                await transaction.RollbackAsync(cancellationToken);
                return CreatePaymentLinkPersistenceResult.Failure(CreatePaymentLinkPersistenceStatus.BookingNotFound);
            }

            if (booking.CustomerUserAccountId != currentUserId &&
                !currentUserRoles.Contains(UserRoleCode.PlatformAdministrator))
            {
                await transaction.RollbackAsync(cancellationToken);
                return CreatePaymentLinkPersistenceResult.Failure(CreatePaymentLinkPersistenceStatus.Forbidden);
            }

            if (booking.Status != BookingStatus.PendingPayment || booking.PaymentMode != PaymentMode.PlatformCollect)
            {
                await transaction.RollbackAsync(cancellationToken);
                return CreatePaymentLinkPersistenceResult.Failure(CreatePaymentLinkPersistenceStatus.BookingNotPendingPayment);
            }

            DateTime utcNow = _dateTimeProvider.UtcNow;
            if (booking.PaymentExpiresAtUtc is null || booking.PaymentExpiresAtUtc <= utcNow)
            {
                Booking? expiredBooking = await _dbContext.Bookings
                    .IgnoreQueryFilters()
                    .FirstOrDefaultAsync(entity => entity.Id == bookingId, cancellationToken);
                expiredBooking?.ExpirePaymentHold(utcNow);
                await _dbContext.SaveChangesAsync(cancellationToken);
                await transaction.CommitAsync(cancellationToken);
                return CreatePaymentLinkPersistenceResult.Failure(CreatePaymentLinkPersistenceStatus.PaymentExpired);
            }

            if (booking.TotalAmount <= 0 || booking.TotalAmount != decimal.Truncate(booking.TotalAmount) || booking.TotalAmount > int.MaxValue)
            {
                await transaction.RollbackAsync(cancellationToken);
                return CreatePaymentLinkPersistenceResult.Failure(CreatePaymentLinkPersistenceStatus.InvalidAmount);
            }

            PaymentTransaction? existingTransaction = await _dbContext.PaymentTransactions
                .IgnoreQueryFilters()
                .Where(payment => payment.BookingId == bookingId && payment.Provider == Provider)
                .OrderByDescending(payment => payment.CreatedAtUtc)
                .FirstOrDefaultAsync(cancellationToken);

            if (existingTransaction is not null)
            {
                if (existingTransaction.Status == PaymentStatus.Paid)
                {
                    await transaction.RollbackAsync(cancellationToken);
                    return CreatePaymentLinkPersistenceResult.Failure(CreatePaymentLinkPersistenceStatus.BookingNotPendingPayment);
                }

                if (!string.IsNullOrWhiteSpace(existingTransaction.CheckoutUrl) &&
                    !string.IsNullOrWhiteSpace(existingTransaction.GatewayReference))
                {
                    await transaction.CommitAsync(cancellationToken);
                    return CreatePaymentLinkPersistenceResult.Existing(ToPaymentLinkDto(booking, existingTransaction));
                }

                if (!string.IsNullOrWhiteSpace(existingTransaction.GatewayReference) &&
                    long.TryParse(existingTransaction.GatewayReference, NumberStyles.None, CultureInfo.InvariantCulture, out long existingOrderCode))
                {
                    await transaction.CommitAsync(cancellationToken);
                    return CreatePaymentLinkPersistenceResult.Prepared(new PreparedPaymentLink(
                        existingTransaction.Id,
                        booking.Id,
                        booking.BookingCode,
                        ToGatewayRequest(booking, existingOrderCode),
                        booking.PaymentExpiresAtUtc.Value));
                }
            }

            long orderCode = await GenerateUniqueOrderCodeAsync(cancellationToken);
            PaymentTransaction paymentTransaction = new(Guid.NewGuid(), booking.HotelId, booking.Id, Provider, booking.TotalAmount);
            paymentTransaction.ReserveGatewayReference(orderCode.ToString(CultureInfo.InvariantCulture));

            await _dbContext.PaymentTransactions.AddAsync(paymentTransaction, cancellationToken);
            await _dbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);

            return CreatePaymentLinkPersistenceResult.Prepared(new PreparedPaymentLink(
                paymentTransaction.Id,
                booking.Id,
                booking.BookingCode,
                ToGatewayRequest(booking, orderCode),
                booking.PaymentExpiresAtUtc.Value));
        });
    }

    public async Task<PaymentLinkDto> AttachPaymentLinkAsync(
        Guid paymentTransactionId,
        CreatePaymentLinkGatewayResult gatewayResult,
        CancellationToken cancellationToken)
    {
        PaymentTransaction paymentTransaction = await _dbContext.PaymentTransactions
            .IgnoreQueryFilters()
            .FirstAsync(payment => payment.Id == paymentTransactionId, cancellationToken);

        BookingPaymentReadModel booking = await _dbContext.Bookings
            .IgnoreQueryFilters()
            .AsNoTracking()
            .Where(entity => entity.Id == paymentTransaction.BookingId)
            .Join(
                _dbContext.UserAccounts.AsNoTracking(),
                booking => booking.CustomerUserAccountId,
                user => user.Id,
                (booking, user) => new BookingPaymentReadModel(
                    booking.Id,
                    booking.BookingCode,
                    booking.CustomerUserAccountId,
                    user.Email,
                    booking.HotelId,
                    booking.Status,
                    booking.PaymentMode,
                    booking.TotalAmount,
                    booking.GuestFullName,
                    booking.GuestPhone,
                    booking.PaymentExpiresAtUtc))
            .FirstAsync(cancellationToken);

        paymentTransaction.AttachPaymentLink(
            gatewayResult.OrderCode.ToString(CultureInfo.InvariantCulture),
            gatewayResult.PaymentLinkId,
            gatewayResult.CheckoutUrl);

        await _dbContext.SaveChangesAsync(cancellationToken);

        return ToPaymentLinkDto(booking, paymentTransaction);
    }

    public async Task<PaymentWebhookPersistenceResult> ProcessWebhookAsync(
        PaymentWebhookRequest request,
        CancellationToken cancellationToken)
    {
        IExecutionStrategy executionStrategy = _dbContext.Database.CreateExecutionStrategy();

        return await executionStrategy.ExecuteAsync(async () =>
        {
            await using IDbContextTransaction transaction = await _dbContext.Database.BeginTransactionAsync(
                IsolationLevel.Serializable,
                cancellationToken);

            string orderCode = request.Data.OrderCode.ToString(CultureInfo.InvariantCulture);
            PaymentTransaction? paymentTransaction = await _dbContext.PaymentTransactions
                .IgnoreQueryFilters()
                .FirstOrDefaultAsync(payment => payment.Provider == Provider && payment.GatewayReference == orderCode, cancellationToken);

            if (paymentTransaction is null)
            {
                await transaction.RollbackAsync(cancellationToken);
                return PaymentWebhookPersistenceResult.Failure(PaymentWebhookPersistenceStatus.TransactionNotFound, "Payment transaction was not found.");
            }

            Booking? booking = await _dbContext.Bookings
                .IgnoreQueryFilters()
                .FirstOrDefaultAsync(entity => entity.Id == paymentTransaction.BookingId, cancellationToken);

            if (booking is null)
            {
                await transaction.RollbackAsync(cancellationToken);
                return PaymentWebhookPersistenceResult.Failure(PaymentWebhookPersistenceStatus.TransactionNotFound, "Booking was not found.");
            }

            if (paymentTransaction.Status == PaymentStatus.Paid && booking.Status == BookingStatus.Confirmed)
            {
                await transaction.CommitAsync(cancellationToken);
                return PaymentWebhookPersistenceResult.Duplicate("Webhook was already processed.");
            }

            if (paymentTransaction.Amount != request.Data.Amount)
            {
                await transaction.RollbackAsync(cancellationToken);
                return PaymentWebhookPersistenceResult.Failure(PaymentWebhookPersistenceStatus.AmountMismatch, "Webhook amount does not match transaction amount.");
            }

            DateTime utcNow = _dateTimeProvider.UtcNow;

            if (!request.Success || request.Code != "00" || request.Data.Code != "00")
            {
                paymentTransaction.MarkFailed();
                await _dbContext.SaveChangesAsync(cancellationToken);
                await transaction.CommitAsync(cancellationToken);
                return PaymentWebhookPersistenceResult.Processed("Webhook did not represent a successful payment and was recorded.");
            }

            if (booking.PaymentExpiresAtUtc is null || booking.PaymentExpiresAtUtc <= utcNow)
            {
                booking.ExpirePaymentHold(utcNow);
                paymentTransaction.MarkFailed();
                await _dbContext.SaveChangesAsync(cancellationToken);
                await transaction.CommitAsync(cancellationToken);
                return PaymentWebhookPersistenceResult.Failure(PaymentWebhookPersistenceStatus.PaymentExpired, "Payment hold has expired.");
            }

            paymentTransaction.MarkPaid(request.Data.Reference, utcNow);
            booking.ConfirmPayment();

            bool commissionExists = await _dbContext.CommissionRecords
                .IgnoreQueryFilters()
                .AnyAsync(commission => commission.BookingId == booking.Id, cancellationToken);

            if (!commissionExists)
            {
                decimal commissionRate = await _dbContext.HotelProperties
                    .IgnoreQueryFilters()
                    .Where(hotel => hotel.Id == booking.HotelId)
                    .Select(hotel => hotel.DefaultCommissionRate)
                    .FirstAsync(cancellationToken);

                await _dbContext.CommissionRecords.AddAsync(
                    new CommissionRecord(Guid.NewGuid(), booking.HotelId, booking.Id, booking.TotalAmount, commissionRate),
                    cancellationToken);
            }

            await _dbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);

            return PaymentWebhookPersistenceResult.Processed("Payment was confirmed.");
        });
    }

    public async Task<SimulatedPaymentPersistenceResult> SimulateSuccessfulPaymentAsync(
        Guid bookingId,
        Guid currentUserId,
        IReadOnlyCollection<UserRoleCode> currentUserRoles,
        CancellationToken cancellationToken)
    {
        IExecutionStrategy executionStrategy = _dbContext.Database.CreateExecutionStrategy();

        return await executionStrategy.ExecuteAsync(async () =>
        {
            await using IDbContextTransaction transaction = await _dbContext.Database.BeginTransactionAsync(
                IsolationLevel.Serializable,
                cancellationToken);

            Booking? booking = await _dbContext.Bookings
                .IgnoreQueryFilters()
                .FirstOrDefaultAsync(entity => entity.Id == bookingId, cancellationToken);

            if (booking is null)
            {
                await transaction.RollbackAsync(cancellationToken);
                return SimulatedPaymentPersistenceResult.Failure(SimulatedPaymentPersistenceStatus.BookingNotFound, "Booking was not found.");
            }

            if (booking.CustomerUserAccountId != currentUserId &&
                !currentUserRoles.Contains(UserRoleCode.PlatformAdministrator))
            {
                await transaction.RollbackAsync(cancellationToken);
                return SimulatedPaymentPersistenceResult.Failure(SimulatedPaymentPersistenceStatus.Forbidden, "Current user cannot confirm this booking.");
            }

            if (booking.Status == BookingStatus.Confirmed)
            {
                await transaction.CommitAsync(cancellationToken);
                return SimulatedPaymentPersistenceResult.Duplicate("Booking was already confirmed.");
            }

            if (booking.Status != BookingStatus.PendingPayment || booking.PaymentMode != PaymentMode.PlatformCollect)
            {
                await transaction.RollbackAsync(cancellationToken);
                return SimulatedPaymentPersistenceResult.Failure(SimulatedPaymentPersistenceStatus.BookingNotPendingPayment, "Booking is not waiting for platform payment.");
            }

            DateTime utcNow = _dateTimeProvider.UtcNow;
            if (booking.PaymentExpiresAtUtc is null || booking.PaymentExpiresAtUtc <= utcNow)
            {
                booking.ExpirePaymentHold(utcNow);
                await _dbContext.SaveChangesAsync(cancellationToken);
                await transaction.CommitAsync(cancellationToken);
                return SimulatedPaymentPersistenceResult.Failure(SimulatedPaymentPersistenceStatus.PaymentExpired, "Payment hold has expired.");
            }

            PaymentTransaction? paymentTransaction = await _dbContext.PaymentTransactions
                .IgnoreQueryFilters()
                .Where(payment => payment.BookingId == booking.Id &&
                    (payment.Provider == SimulatedProvider || payment.Provider == Provider))
                .OrderByDescending(payment => payment.CreatedAtUtc)
                .FirstOrDefaultAsync(cancellationToken);

            string simulationReference = $"SIM-{booking.BookingCode}-{utcNow:yyyyMMddHHmmss}";

            if (paymentTransaction is null || paymentTransaction.Status is PaymentStatus.Failed or PaymentStatus.Cancelled)
            {
                paymentTransaction = new PaymentTransaction(Guid.NewGuid(), booking.HotelId, booking.Id, SimulatedProvider, booking.TotalAmount);
                paymentTransaction.ReserveGatewayReference(simulationReference);
                await _dbContext.PaymentTransactions.AddAsync(paymentTransaction, cancellationToken);
            }
            else if (paymentTransaction.GatewayReference is null)
            {
                paymentTransaction.ReserveGatewayReference(simulationReference);
            }

            paymentTransaction.MarkPaid(simulationReference, utcNow);
            booking.ConfirmPayment();

            await EnsureCommissionRecordAsync(booking, cancellationToken);

            await _dbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);

            return SimulatedPaymentPersistenceResult.Processed("Booking was confirmed by simulated payment.");
        });
    }

    private async Task<long> GenerateUniqueOrderCodeAsync(CancellationToken cancellationToken)
    {
        for (int attempt = 0; attempt < 10; attempt++)
        {
            long orderCode = Random.Shared.NextInt64(100_000_000_000, 999_999_999_999);
            string orderCodeText = orderCode.ToString(CultureInfo.InvariantCulture);
            bool exists = await _dbContext.PaymentTransactions
                .IgnoreQueryFilters()
                .AnyAsync(payment => payment.GatewayReference == orderCodeText, cancellationToken);

            if (!exists)
            {
                return orderCode;
            }
        }

        return DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
    }

    private async Task EnsureCommissionRecordAsync(Booking booking, CancellationToken cancellationToken)
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
            new CommissionRecord(Guid.NewGuid(), booking.HotelId, booking.Id, booking.TotalAmount, commissionRate),
            cancellationToken);
    }

    private static CreatePaymentLinkGatewayRequest ToGatewayRequest(
        BookingPaymentReadModel booking,
        long orderCode)
    {
        return new CreatePaymentLinkGatewayRequest(
            orderCode,
            Convert.ToInt32(booking.TotalAmount, CultureInfo.InvariantCulture),
            $"BOOKING {booking.BookingCode}",
            booking.GuestFullName,
            booking.CustomerEmail,
            booking.GuestPhone,
            booking.PaymentExpiresAtUtc!.Value);
    }

    private static PaymentLinkDto ToPaymentLinkDto(
        BookingPaymentReadModel booking,
        PaymentTransaction paymentTransaction)
    {
        return new PaymentLinkDto(
            booking.Id,
            booking.BookingCode,
            long.Parse(paymentTransaction.GatewayReference!, CultureInfo.InvariantCulture),
            paymentTransaction.Amount,
            paymentTransaction.CheckoutUrl!,
            paymentTransaction.GatewayPaymentLinkId,
            booking.PaymentExpiresAtUtc!.Value);
    }

    private sealed record BookingPaymentReadModel(
        Guid Id,
        string BookingCode,
        Guid CustomerUserAccountId,
        string CustomerEmail,
        Guid HotelId,
        BookingStatus Status,
        PaymentMode PaymentMode,
        decimal TotalAmount,
        string GuestFullName,
        string GuestPhone,
        DateTime? PaymentExpiresAtUtc);
}
