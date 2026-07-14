using FluentValidation;
using HotelMarketplace.Application.Marketplace.Requests;
using HotelMarketplace.SharedKernel.Time;

namespace HotelMarketplace.Application.Marketplace.Validation;

internal sealed class HotelSearchRequestValidator : AbstractValidator<HotelSearchRequest>
{
    public HotelSearchRequestValidator(IDateTimeProvider dateTimeProvider)
    {
        RuleFor(request => request.Location).MaximumLength(100);
        RuleFor(request => request.CheckInDate)
            .GreaterThanOrEqualTo(dateTimeProvider.Today)
            .WithMessage("Check-in date cannot be in the past.");
        RuleFor(request => request.CheckOutDate)
            .GreaterThan(request => request.CheckInDate)
            .WithMessage("Check-out date must be after check-in date.");
        RuleFor(request => request.GuestCount).GreaterThan(0);
        RuleFor(request => request.RoomCount).GreaterThan(0);
    }
}

internal sealed class HotelDetailAvailabilityRequestValidator : AbstractValidator<HotelDetailAvailabilityRequest>
{
    public HotelDetailAvailabilityRequestValidator(IDateTimeProvider dateTimeProvider)
    {
        RuleFor(request => request.CheckInDate)
            .GreaterThanOrEqualTo(dateTimeProvider.Today)
            .WithMessage("Check-in date cannot be in the past.");
        RuleFor(request => request.CheckOutDate)
            .GreaterThan(request => request.CheckInDate)
            .WithMessage("Check-out date must be after check-in date.");
        RuleFor(request => request.GuestCount).GreaterThan(0);
        RuleFor(request => request.RoomCount).GreaterThan(0);
    }
}
