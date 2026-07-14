using FluentValidation;
using HotelMarketplace.Application.HotelManagement.Requests;
using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.HotelManagement.Validation;

internal sealed class RegisterHotelRequestValidator : AbstractValidator<RegisterHotelRequest>
{
    public RegisterHotelRequestValidator()
    {
        RuleFor(request => request.Name).NotEmpty().MaximumLength(200);
        RuleFor(request => request.City).NotEmpty().MaximumLength(100);
        RuleFor(request => request.AddressLine).NotEmpty().MaximumLength(300);
        RuleFor(request => request.ContactEmail).NotEmpty().EmailAddress().MaximumLength(256);
        RuleFor(request => request.ContactPhone).NotEmpty().MaximumLength(32);
        RuleFor(request => request.Description).MaximumLength(2000);
    }
}

internal sealed class UpdateHotelProfileRequestValidator : AbstractValidator<UpdateHotelProfileRequest>
{
    public UpdateHotelProfileRequestValidator()
    {
        RuleFor(request => request.Name).NotEmpty().MaximumLength(200);
        RuleFor(request => request.City).NotEmpty().MaximumLength(100);
        RuleFor(request => request.AddressLine).NotEmpty().MaximumLength(300);
        RuleFor(request => request.ContactEmail).NotEmpty().EmailAddress().MaximumLength(256);
        RuleFor(request => request.ContactPhone).NotEmpty().MaximumLength(32);
        RuleFor(request => request.Description).MaximumLength(2000);
    }
}

internal sealed class CreateRoomTypeRequestValidator : AbstractValidator<CreateRoomTypeRequest>
{
    public CreateRoomTypeRequestValidator()
    {
        RuleFor(request => request.Name).NotEmpty().MaximumLength(160);
        RuleFor(request => request.AdultCapacity).GreaterThan(0);
        RuleFor(request => request.ChildCapacity).GreaterThanOrEqualTo(0);
        RuleFor(request => request.BasePricePerNight).GreaterThanOrEqualTo(0);
        RuleFor(request => request.Description).MaximumLength(1000);
    }
}

internal sealed class UpdateRoomTypeRequestValidator : AbstractValidator<UpdateRoomTypeRequest>
{
    public UpdateRoomTypeRequestValidator()
    {
        RuleFor(request => request.Name).NotEmpty().MaximumLength(160);
        RuleFor(request => request.AdultCapacity).GreaterThan(0);
        RuleFor(request => request.ChildCapacity).GreaterThanOrEqualTo(0);
        RuleFor(request => request.BasePricePerNight).GreaterThanOrEqualTo(0);
        RuleFor(request => request.Description).MaximumLength(1000);
    }
}

internal sealed class CreatePhysicalRoomRequestValidator : AbstractValidator<CreatePhysicalRoomRequest>
{
    public CreatePhysicalRoomRequestValidator()
    {
        RuleFor(request => request.RoomTypeId).NotEmpty();
        RuleFor(request => request.RoomNumber).NotEmpty().MaximumLength(32);
        RuleFor(request => request.InitialStatus)
            .Must(status => status is RoomOperationalStatus.Available or RoomOperationalStatus.Dirty or RoomOperationalStatus.Maintenance or RoomOperationalStatus.OutOfService)
            .WithMessage("Initial status must be Available, Dirty, Maintenance, or OutOfService.");
    }
}

internal sealed class UpdatePhysicalRoomRequestValidator : AbstractValidator<UpdatePhysicalRoomRequest>
{
    public UpdatePhysicalRoomRequestValidator()
    {
        RuleFor(request => request.RoomNumber).NotEmpty().MaximumLength(32);
        RuleFor(request => request.Status)
            .Must(status => status is RoomOperationalStatus.Available or RoomOperationalStatus.Dirty or RoomOperationalStatus.Maintenance or RoomOperationalStatus.OutOfService or RoomOperationalStatus.Inactive)
            .WithMessage("Status must be Available, Dirty, Maintenance, OutOfService, or Inactive.");
    }
}
