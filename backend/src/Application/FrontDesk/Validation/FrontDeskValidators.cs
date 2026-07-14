using FluentValidation;
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
        RuleFor(request => request.GuestFullName).NotEmpty().MaximumLength(200);
        RuleFor(request => request.IdentityDocumentNumber).MaximumLength(64);
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
            .WithMessage("Check-in date cannot be in the past.");
        RuleFor(request => request.CheckOutDate)
            .GreaterThan(request => request.CheckInDate)
            .WithMessage("Check-out date must be after check-in date.");
        RuleFor(request => request.GuestCount).GreaterThan(0);
        RuleFor(request => request.GuestFullName).NotEmpty().MaximumLength(200);
        RuleFor(request => request.GuestPhone).NotEmpty().MaximumLength(32);
        RuleFor(request => request.IdentityDocumentNumber).MaximumLength(64);
        RuleFor(request => request.CashCollectedAmount).GreaterThanOrEqualTo(0);
    }
}
