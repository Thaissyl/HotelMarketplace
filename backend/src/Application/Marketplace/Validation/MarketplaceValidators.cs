using FluentValidation;
using HotelMarketplace.Application.Common.Validation;
using HotelMarketplace.Application.Marketplace.Requests;
using HotelMarketplace.SharedKernel.Time;

namespace HotelMarketplace.Application.Marketplace.Validation;

internal sealed class HotelSearchRequestValidator : AbstractValidator<HotelSearchRequest>
{
    private const int MaximumAdvanceBookingDays = 365;
    private const int MaximumStayNights = 30;

    public HotelSearchRequestValidator(IDateTimeProvider dateTimeProvider)
    {
        RuleFor(request => request.Location).SafeOptionalText(100, "Location");
        RuleFor(request => request.CheckInDate)
            .GreaterThanOrEqualTo(dateTimeProvider.Today)
            .WithMessage("Check-in date cannot be in the past.")
            .LessThanOrEqualTo(dateTimeProvider.Today.AddDays(MaximumAdvanceBookingDays))
            .WithMessage($"Check-in date cannot be more than {MaximumAdvanceBookingDays} days in advance.");
        RuleFor(request => request.CheckOutDate)
            .GreaterThan(request => request.CheckInDate)
            .WithMessage("Check-out date must be after check-in date.")
            .Must((request, checkOutDate) => checkOutDate.DayNumber - request.CheckInDate.DayNumber <= MaximumStayNights)
            .WithMessage($"Stay length cannot exceed {MaximumStayNights} nights.");
        RuleFor(request => request.GuestCount).InclusiveBetween(1, 30);
        RuleFor(request => request.RoomCount).InclusiveBetween(1, 10);
    }
}

internal sealed class HotelDetailAvailabilityRequestValidator : AbstractValidator<HotelDetailAvailabilityRequest>
{
    private const int MaximumAdvanceBookingDays = 365;
    private const int MaximumStayNights = 30;

    public HotelDetailAvailabilityRequestValidator(IDateTimeProvider dateTimeProvider)
    {
        RuleFor(request => request.CheckInDate)
            .GreaterThanOrEqualTo(dateTimeProvider.Today)
            .WithMessage("Check-in date cannot be in the past.")
            .LessThanOrEqualTo(dateTimeProvider.Today.AddDays(MaximumAdvanceBookingDays))
            .WithMessage($"Check-in date cannot be more than {MaximumAdvanceBookingDays} days in advance.");
        RuleFor(request => request.CheckOutDate)
            .GreaterThan(request => request.CheckInDate)
            .WithMessage("Check-out date must be after check-in date.")
            .Must((request, checkOutDate) => checkOutDate.DayNumber - request.CheckInDate.DayNumber <= MaximumStayNights)
            .WithMessage($"Stay length cannot exceed {MaximumStayNights} nights.");
        RuleFor(request => request.GuestCount).InclusiveBetween(1, 30);
        RuleFor(request => request.RoomCount).InclusiveBetween(1, 10);
    }
}
