using HotelMarketplace.Application.Payments.Dtos;
using HotelMarketplace.Application.Payments.Requests;
using HotelMarketplace.Application.Security;
using HotelMarketplace.SharedKernel.Results;

namespace HotelMarketplace.Application.Payments;

internal sealed class PaymentService : IPaymentService
{
    private readonly IPaymentRepository _paymentRepository;
    private readonly ICurrentUserService _currentUserService;

    public PaymentService(
        IPaymentRepository paymentRepository,
        ICurrentUserService currentUserService)
    {
        _paymentRepository = paymentRepository;
        _currentUserService = currentUserService;
    }

    public async Task<Result<DemoPaymentResultDto>> ConfirmDemoPaymentAsync(
        Guid bookingId,
        ConfirmDemoPaymentRequest request,
        CancellationToken cancellationToken)
    {
        if (_currentUserService.UserId is null)
        {
            return Result.Failure<DemoPaymentResultDto>(PaymentErrors.Forbidden);
        }

        if (request.Amount <= 0)
        {
            return Result.Failure<DemoPaymentResultDto>(PaymentErrors.InvalidAmount);
        }

        DemoPaymentPersistenceResult persistenceResult = await _paymentRepository.ConfirmDemoPaymentAsync(
            bookingId,
            _currentUserService.UserId.Value,
            request,
            cancellationToken);

        return persistenceResult.Status switch
        {
            DemoPaymentPersistenceStatus.Processed => Result.Success(persistenceResult.Payment!),
            DemoPaymentPersistenceStatus.Duplicate => Result.Success(persistenceResult.Payment!),
            DemoPaymentPersistenceStatus.Forbidden => Result.Failure<DemoPaymentResultDto>(PaymentErrors.Forbidden),
            DemoPaymentPersistenceStatus.BookingNotFound => Result.Failure<DemoPaymentResultDto>(PaymentErrors.BookingNotFound),
            DemoPaymentPersistenceStatus.BookingNotPendingPayment => Result.Failure<DemoPaymentResultDto>(PaymentErrors.BookingNotPendingPayment),
            DemoPaymentPersistenceStatus.PaymentExpired => Result.Failure<DemoPaymentResultDto>(PaymentErrors.PaymentExpired),
            DemoPaymentPersistenceStatus.AmountMismatch => Result.Failure<DemoPaymentResultDto>(PaymentErrors.AmountMismatch),
            DemoPaymentPersistenceStatus.LockUnavailable => Result.Failure<DemoPaymentResultDto>(PaymentErrors.LockUnavailable),
            _ => Result.Failure<DemoPaymentResultDto>(PaymentErrors.BookingNotFound)
        };
    }
}
