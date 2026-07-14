using FluentValidation;
using HotelMarketplace.Application.Bookings.Requests;
using HotelMarketplace.SharedKernel.Time;

namespace HotelMarketplace.Application.Bookings.Validation;

internal sealed class CreateBookingRequestValidator : AbstractValidator<CreateBookingRequest>
{
    public CreateBookingRequestValidator(IDateTimeProvider dateTimeProvider)
    {
        RuleFor(request => request.HotelId).NotEmpty();
        RuleFor(request => request.RoomTypeId).NotEmpty();
        RuleFor(request => request.CheckInDate)
            .GreaterThanOrEqualTo(dateTimeProvider.Today)
            .WithMessage("Check-in date cannot be in the past.");
        RuleFor(request => request.CheckOutDate)
            .GreaterThan(request => request.CheckInDate)
            .WithMessage("Check-out date must be after check-in date.");
        RuleFor(request => request.RoomCount).GreaterThan(0);
        RuleFor(request => request.GuestCount).GreaterThan(0);
        RuleFor(request => request.GuestFullName).NotEmpty().MaximumLength(200);
        RuleFor(request => request.GuestPhone).NotEmpty().MaximumLength(32);
    }
}
