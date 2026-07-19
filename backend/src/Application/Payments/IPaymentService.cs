using HotelMarketplace.Application.Payments.Dtos;
using HotelMarketplace.Application.Payments.Requests;
using HotelMarketplace.SharedKernel.Results;

namespace HotelMarketplace.Application.Payments;

public interface IPaymentService
{
    Task<Result<DemoPaymentResultDto>> ConfirmDemoPaymentAsync(
        Guid bookingId,
        ConfirmDemoPaymentRequest request,
        CancellationToken cancellationToken);
}
