using FluentValidation;
using HotelMarketplace.Application.Common.Validation;
using HotelMarketplace.Application.Bookings.Requests;
using HotelMarketplace.SharedKernel.Time;

namespace HotelMarketplace.Application.Bookings.Validation;

internal sealed class CreateBookingRequestValidator : AbstractValidator<CreateBookingRequest>
{
    private const int MaximumAdvanceBookingDays = 365;
    private const int MaximumStayNights = 30;

    public CreateBookingRequestValidator(IDateTimeProvider dateTimeProvider)
    {
        RuleFor(request => request.HotelId).NotEmpty();
        RuleFor(request => request.RoomTypeId).NotEmpty();
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
        RuleFor(request => request.RoomCount).InclusiveBetween(1, 10);
        RuleFor(request => request.GuestCount).InclusiveBetween(1, 30);
        RuleFor(request => request.GuestFullName).SafeRequiredText(200, "Guest full name");
        RuleFor(request => request.GuestPhone).TenDigitPhone("Guest phone");
    }
}
