using HotelMarketplace.Application.Payments.Dtos;
using HotelMarketplace.Application.Payments.Models;
using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.Payments;

public interface IPaymentRepository
{
    Task<CreatePaymentLinkPersistenceResult> PreparePaymentLinkAsync(
        Guid bookingId,
        Guid currentUserId,
        IReadOnlyCollection<UserRoleCode> currentUserRoles,
        CancellationToken cancellationToken);

    Task<PaymentLinkDto> AttachPaymentLinkAsync(
        Guid paymentTransactionId,
        CreatePaymentLinkGatewayResult gatewayResult,
        CancellationToken cancellationToken);

    Task<SimulatedPaymentPersistenceResult> SimulateSuccessfulPaymentAsync(
        Guid bookingId,
        Guid currentUserId,
        IReadOnlyCollection<UserRoleCode> currentUserRoles,
        CancellationToken cancellationToken);

    Task<PaymentWebhookPersistenceResult> ProcessWebhookAsync(
        PaymentWebhookRequest request,
        CancellationToken cancellationToken);
}
