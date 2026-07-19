using FluentValidation;
using HotelMarketplace.Application.Availability.Requests;
using HotelMarketplace.Domain.Enums;
using HotelMarketplace.SharedKernel.Time;

namespace HotelMarketplace.Application.Availability.Validation;

internal sealed class AvailabilityCalendarRequestValidator : AbstractValidator<AvailabilityCalendarRequest>
{
    public AvailabilityCalendarRequestValidator()
    {
        RuleFor(request => request.EndDate)
            .GreaterThan(request => request.StartDate)
            .WithMessage("End date must be later than start date.");
        RuleFor(request => request)
            .Must(request => request.PhysicalRoomId is null || request.RoomTypeId is not null)
            .WithMessage("A room type is required when filtering by physical room.");
    }
}

internal sealed class ChangeAvailabilityRequestValidator : AbstractValidator<ChangeAvailabilityRequest>
{
    public ChangeAvailabilityRequestValidator(IDateTimeProvider dateTimeProvider)
    {
        RuleFor(request => request.RoomTypeId).NotEmpty();
        RuleFor(request => request.Action).IsInEnum();
        RuleFor(request => request.StartDate)
            .GreaterThanOrEqualTo(dateTimeProvider.Today)
            .WithMessage("Start date cannot be in the past.");
        RuleFor(request => request.EndDate)
            .GreaterThan(request => request.StartDate)
            .WithMessage("End date must be later than start date.");
        RuleFor(request => request.EndDate)
            .LessThanOrEqualTo(request => request.StartDate.AddYears(2))
            .WithMessage("An availability change cannot exceed two years.");
        RuleFor(request => request.Reason)
            .NotEmpty()
            .When(request => request.Action is AvailabilityChangeAction.Close or AvailabilityChangeAction.Block)
            .WithMessage("Please enter a required reason for this availability change.");
        RuleFor(request => request.Reason).MaximumLength(500);
    }
}
