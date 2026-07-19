using FluentValidation;
using HotelMarketplace.Application.Bookings.Requests;
using HotelMarketplace.Application.Common.Validation;

namespace HotelMarketplace.Application.Bookings.Validation;

internal sealed class CancelBookingRequestValidator : AbstractValidator<CancelBookingRequest>
{
    public CancelBookingRequestValidator()
    {
        RuleFor(request => request.Reason).SafeRequiredText(500, "Cancellation reason");
    }
}
