using HotelMarketplace.Application.Payments.Requests;

namespace HotelMarketplace.Application.Payments;

public interface IPaymentRepository
{
    Task<DemoPaymentPersistenceResult> ConfirmDemoPaymentAsync(
        Guid bookingId,
        Guid currentUserId,
        ConfirmDemoPaymentRequest request,
        CancellationToken cancellationToken);
}
