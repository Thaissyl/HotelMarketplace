using HotelMarketplace.Application.Payments.Models;

namespace HotelMarketplace.Application.Payments;

public interface IPayOsGateway
{
    Task<CreatePaymentLinkGatewayResult> CreatePaymentLinkAsync(
        CreatePaymentLinkGatewayRequest request,
        CancellationToken cancellationToken);

    bool VerifyWebhook(PaymentWebhookRequest request);
}
