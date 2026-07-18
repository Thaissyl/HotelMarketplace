using FluentValidation;
using HotelMarketplace.Application.Common.Validation;
using HotelMarketplace.Application.FrontDesk.Requests;
using HotelMarketplace.SharedKernel.Time;

namespace HotelMarketplace.Application.FrontDesk.Validation;

internal sealed class CheckInBookingRequestValidator : AbstractValidator<CheckInBookingRequest>
{
    public CheckInBookingRequestValidator()
    {
        RuleFor(request => request.PhysicalRoomIds).NotEmpty();
        RuleForEach(request => request.PhysicalRoomIds).NotEmpty();
        RuleFor(request => request.PhysicalRoomIds)
            .Must(roomIds => roomIds is not null && roomIds.Distinct().Count() == roomIds.Count)
            .WithMessage("Physical room ids must be unique.");
        RuleFor(request => request.GuestFullName).SafeRequiredText(200, "Guest full name");
        RuleFor(request => request.IdentityDocumentNumber).SafeOptionalText(64, "Identity document number");
    }
}

internal sealed class CheckOutBookingRequestValidator : AbstractValidator<CheckOutBookingRequest>
{
    public CheckOutBookingRequestValidator()
    {
        RuleFor(request => request.CashCollectedAmount).GreaterThanOrEqualTo(0);
    }
}

internal sealed class CreateWalkInBookingRequestValidator : AbstractValidator<CreateWalkInBookingRequest>
{
    private const int MaximumAdvanceBookingDays = 365;
    private const int MaximumStayNights = 30;

    public CreateWalkInBookingRequestValidator(IDateTimeProvider dateTimeProvider)
    {
        RuleFor(request => request.RoomTypeId).NotEmpty();
        RuleFor(request => request.PhysicalRoomIds).NotEmpty();
        RuleForEach(request => request.PhysicalRoomIds).NotEmpty();
        RuleFor(request => request.PhysicalRoomIds)
            .Must(roomIds => roomIds is not null && roomIds.Distinct().Count() == roomIds.Count)
            .WithMessage("Physical room ids must be unique.");
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
        RuleFor(request => request.GuestFullName).SafeRequiredText(200, "Guest full name");
        RuleFor(request => request.GuestPhone).TenDigitPhone("Guest phone");
        RuleFor(request => request.IdentityDocumentNumber).SafeOptionalText(64, "Identity document number");
        RuleFor(request => request.CashCollectedAmount).GreaterThanOrEqualTo(0);
    }
}
