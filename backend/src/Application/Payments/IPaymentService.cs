using HotelMarketplace.Application.Payments.Dtos;
using HotelMarketplace.Application.Payments.Models;
using HotelMarketplace.SharedKernel.Results;

namespace HotelMarketplace.Application.Payments;

public interface IPaymentService
{
    Task<Result<PaymentLinkDto>> CreatePaymentLinkAsync(
        Guid bookingId,
        CancellationToken cancellationToken);

    Task<Result<PaymentWebhookResultDto>> SimulateSuccessfulPaymentAsync(
        Guid bookingId,
        CancellationToken cancellationToken);

    Task<Result<PaymentWebhookResultDto>> HandlePayOsWebhookAsync(
        PaymentWebhookRequest request,
        CancellationToken cancellationToken);
}
