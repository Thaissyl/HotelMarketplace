using FluentValidation;
using HotelMarketplace.Application.Common.Validation;
using HotelMarketplace.Application.HotelManagement.Requests;
using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.HotelManagement.Validation;

internal sealed class RegisterHotelRequestValidator : AbstractValidator<RegisterHotelRequest>
{
    public RegisterHotelRequestValidator()
    {
        RuleFor(request => request.Name).SafeRequiredText(200, "Hotel name");
        RuleFor(request => request.City).SafeRequiredText(100, "City");
        RuleFor(request => request.AddressLine).SafeRequiredText(300, "Address line");
        RuleFor(request => request.ContactEmail).NotEmpty().EmailAddress().MaximumLength(256);
        RuleFor(request => request.ContactPhone).TenDigitPhone("Contact phone");
        RuleFor(request => request.Description).SafeOptionalText(2000, "Description");
    }
}

internal sealed class UpdateHotelProfileRequestValidator : AbstractValidator<UpdateHotelProfileRequest>
{
    public UpdateHotelProfileRequestValidator()
    {
        RuleFor(request => request.Name).SafeRequiredText(200, "Hotel name");
        RuleFor(request => request.City).SafeRequiredText(100, "City");
        RuleFor(request => request.AddressLine).SafeRequiredText(300, "Address line");
        RuleFor(request => request.ContactEmail).NotEmpty().EmailAddress().MaximumLength(256);
        RuleFor(request => request.ContactPhone).TenDigitPhone("Contact phone");
        RuleFor(request => request.Description).SafeOptionalText(2000, "Description");
    }
}

internal sealed class CreateRoomTypeRequestValidator : AbstractValidator<CreateRoomTypeRequest>
{
    public CreateRoomTypeRequestValidator()
    {
        RuleFor(request => request.Name).SafeRequiredText(160, "Room type name");
        RuleFor(request => request.AdultCapacity).GreaterThan(0);
        RuleFor(request => request.ChildCapacity).GreaterThanOrEqualTo(0);
        RuleFor(request => request.BasePricePerNight).GreaterThanOrEqualTo(0);
        RuleFor(request => request.Description).SafeOptionalText(1000, "Description");
    }
}

internal sealed class UpdateRoomTypeRequestValidator : AbstractValidator<UpdateRoomTypeRequest>
{
    public UpdateRoomTypeRequestValidator()
    {
        RuleFor(request => request.Name).SafeRequiredText(160, "Room type name");
        RuleFor(request => request.AdultCapacity).GreaterThan(0);
        RuleFor(request => request.ChildCapacity).GreaterThanOrEqualTo(0);
        RuleFor(request => request.BasePricePerNight).GreaterThanOrEqualTo(0);
        RuleFor(request => request.Description).SafeOptionalText(1000, "Description");
    }
}

internal sealed class CreatePhysicalRoomRequestValidator : AbstractValidator<CreatePhysicalRoomRequest>
{
    public CreatePhysicalRoomRequestValidator()
    {
        RuleFor(request => request.RoomTypeId).NotEmpty();
        RuleFor(request => request.RoomNumber).SafeRequiredText(32, "Room number");
        RuleFor(request => request.InitialStatus)
            .Must(status => status is RoomOperationalStatus.Available or RoomOperationalStatus.Dirty or RoomOperationalStatus.Maintenance or RoomOperationalStatus.OutOfService)
            .WithMessage("Initial status must be Available, Dirty, Maintenance, or OutOfService.");
    }
}

internal sealed class UpdatePhysicalRoomRequestValidator : AbstractValidator<UpdatePhysicalRoomRequest>
{
    public UpdatePhysicalRoomRequestValidator()
    {
        RuleFor(request => request.RoomNumber).SafeRequiredText(32, "Room number");
        RuleFor(request => request.Status)
            .Must(status => status is RoomOperationalStatus.Available or RoomOperationalStatus.Dirty or RoomOperationalStatus.Maintenance or RoomOperationalStatus.OutOfService or RoomOperationalStatus.Inactive)
            .WithMessage("Status must be Available, Dirty, Maintenance, OutOfService, or Inactive.");
    }
}
