using HotelMarketplace.Application.Payments.Dtos;
using HotelMarketplace.Application.Payments.Models;
using HotelMarketplace.Application.Security;
using HotelMarketplace.SharedKernel.Results;

namespace HotelMarketplace.Application.Payments;

internal sealed class PaymentService : IPaymentService
{
    private readonly IPaymentRepository _paymentRepository;
    private readonly IPayOsGateway _payOsGateway;
    private readonly ICurrentUserService _currentUserService;

    public PaymentService(
        IPaymentRepository paymentRepository,
        IPayOsGateway payOsGateway,
        ICurrentUserService currentUserService)
    {
        _paymentRepository = paymentRepository;
        _payOsGateway = payOsGateway;
        _currentUserService = currentUserService;
    }

    public async Task<Result<PaymentLinkDto>> CreatePaymentLinkAsync(
        Guid bookingId,
        CancellationToken cancellationToken)
    {
        if (_currentUserService.UserId is null)
        {
            return Result.Failure<PaymentLinkDto>(PaymentErrors.Forbidden);
        }

        CreatePaymentLinkPersistenceResult persistenceResult = await _paymentRepository.PreparePaymentLinkAsync(
            bookingId,
            _currentUserService.UserId.Value,
            _currentUserService.Roles,
            cancellationToken);

        if (persistenceResult.Status == CreatePaymentLinkPersistenceStatus.ExistingPaymentLink)
        {
            return Result.Success(persistenceResult.ExistingPaymentLink!);
        }

        if (persistenceResult.Status != CreatePaymentLinkPersistenceStatus.Prepared)
        {
            return Result.Failure<PaymentLinkDto>(MapCreateLinkError(persistenceResult.Status));
        }

        PreparedPaymentLink preparedPaymentLink = persistenceResult.PreparedPaymentLink!;

        CreatePaymentLinkGatewayResult gatewayResult;
        try
        {
            gatewayResult = await _payOsGateway.CreatePaymentLinkAsync(preparedPaymentLink.GatewayRequest, cancellationToken);
        }
        catch (InvalidOperationException)
        {
            return Result.Failure<PaymentLinkDto>(PaymentErrors.GatewayRejected);
        }

        PaymentLinkDto paymentLink = await _paymentRepository.AttachPaymentLinkAsync(
            preparedPaymentLink.PaymentTransactionId,
            gatewayResult,
            cancellationToken);

        return Result.Success(paymentLink);
    }

    public async Task<Result<PaymentWebhookResultDto>> HandlePayOsWebhookAsync(
        PaymentWebhookRequest request,
        CancellationToken cancellationToken)
    {
        if (!_payOsGateway.VerifyWebhook(request))
        {
            return Result.Failure<PaymentWebhookResultDto>(PaymentErrors.InvalidWebhookSignature);
        }

        PaymentWebhookPersistenceResult persistenceResult = await _paymentRepository.ProcessWebhookAsync(request, cancellationToken);

        return persistenceResult.Status switch
        {
            PaymentWebhookPersistenceStatus.Processed => Result.Success(new PaymentWebhookResultDto("processed", persistenceResult.Message)),
            PaymentWebhookPersistenceStatus.Duplicate => Result.Success(new PaymentWebhookResultDto("duplicate", persistenceResult.Message)),
            PaymentWebhookPersistenceStatus.TransactionNotFound => Result.Failure<PaymentWebhookResultDto>(PaymentErrors.PaymentTransactionNotFound),
            PaymentWebhookPersistenceStatus.AmountMismatch => Result.Failure<PaymentWebhookResultDto>(PaymentErrors.WebhookAmountMismatch),
            PaymentWebhookPersistenceStatus.PaymentExpired => Result.Failure<PaymentWebhookResultDto>(PaymentErrors.PaymentExpired),
            _ => Result.Failure<PaymentWebhookResultDto>(PaymentErrors.PaymentTransactionNotFound)
        };
    }

    public async Task<Result<PaymentWebhookResultDto>> SimulateSuccessfulPaymentAsync(
        Guid bookingId,
        CancellationToken cancellationToken)
    {
        if (_currentUserService.UserId is null)
        {
            return Result.Failure<PaymentWebhookResultDto>(PaymentErrors.Forbidden);
        }

        SimulatedPaymentPersistenceResult persistenceResult = await _paymentRepository.SimulateSuccessfulPaymentAsync(
            bookingId,
            _currentUserService.UserId.Value,
            _currentUserService.Roles,
            cancellationToken);

        return persistenceResult.Status switch
        {
            SimulatedPaymentPersistenceStatus.Processed => Result.Success(new PaymentWebhookResultDto("processed", persistenceResult.Message)),
            SimulatedPaymentPersistenceStatus.Duplicate => Result.Success(new PaymentWebhookResultDto("duplicate", persistenceResult.Message)),
            SimulatedPaymentPersistenceStatus.Forbidden => Result.Failure<PaymentWebhookResultDto>(PaymentErrors.Forbidden),
            SimulatedPaymentPersistenceStatus.BookingNotFound => Result.Failure<PaymentWebhookResultDto>(PaymentErrors.BookingNotFound),
            SimulatedPaymentPersistenceStatus.BookingNotPendingPayment => Result.Failure<PaymentWebhookResultDto>(PaymentErrors.BookingNotPendingPayment),
            SimulatedPaymentPersistenceStatus.PaymentExpired => Result.Failure<PaymentWebhookResultDto>(PaymentErrors.PaymentExpired),
            _ => Result.Failure<PaymentWebhookResultDto>(PaymentErrors.BookingNotFound)
        };
    }

    private static ResultError MapCreateLinkError(CreatePaymentLinkPersistenceStatus status)
    {
        return status switch
        {
            CreatePaymentLinkPersistenceStatus.Forbidden => PaymentErrors.Forbidden,
            CreatePaymentLinkPersistenceStatus.BookingNotFound => PaymentErrors.BookingNotFound,
            CreatePaymentLinkPersistenceStatus.BookingNotPendingPayment => PaymentErrors.BookingNotPendingPayment,
            CreatePaymentLinkPersistenceStatus.PaymentExpired => PaymentErrors.PaymentExpired,
            CreatePaymentLinkPersistenceStatus.InvalidAmount => PaymentErrors.InvalidAmount,
            _ => PaymentErrors.BookingNotFound
        };
    }
}
