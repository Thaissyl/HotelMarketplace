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

internal sealed class CreateHotelStaffRequestValidator : AbstractValidator<CreateHotelStaffRequest>
{
    public CreateHotelStaffRequestValidator()
    {
        RuleFor(request => request.Email).NotEmpty().EmailAddress().MaximumLength(256);
        RuleFor(request => request.Password)
            .NotEmpty()
            .MinimumLength(8)
            .MaximumLength(128)
            .Matches("[A-Z]").WithMessage("Password must contain at least one uppercase letter.")
            .Matches("[a-z]").WithMessage("Password must contain at least one lowercase letter.")
            .Matches("[0-9]").WithMessage("Password must contain at least one number.");
        RuleFor(request => request.FullName).SafeRequiredText(200, "Full name");
        RuleFor(request => request.PhoneNumber).TenDigitPhone("Phone number");
        RuleFor(request => request.Role)
            .Must(role => role is UserRoleCode.HotelManager
                or UserRoleCode.Receptionist
                or UserRoleCode.HousekeepingStaff
                or UserRoleCode.MaintenanceStaff)
            .WithMessage("Staff role must be HotelManager, Receptionist, HousekeepingStaff, or MaintenanceStaff.");
    }
}

internal sealed class AttachHotelStaffRequestValidator : AbstractValidator<AttachHotelStaffRequest>
{
    public AttachHotelStaffRequestValidator()
    {
        RuleFor(request => request.Email).NotEmpty().EmailAddress().MaximumLength(256);
        RuleFor(request => request.Role).Must(IsStaffRole).WithMessage("The selected hotel role is invalid.");
    }

    private static bool IsStaffRole(UserRoleCode role) =>
        role is UserRoleCode.HotelManager or UserRoleCode.Receptionist or
            UserRoleCode.HousekeepingStaff or UserRoleCode.MaintenanceStaff;
}

internal sealed class UpdateHotelStaffAssignmentRequestValidator : AbstractValidator<UpdateHotelStaffAssignmentRequest>
{
    public UpdateHotelStaffAssignmentRequestValidator()
    {
        RuleFor(request => request)
            .Must(request => request.Role.HasValue ^ request.IsActive.HasValue)
            .WithMessage("Provide either Role or IsActive, but not both.");
        RuleFor(request => request.Role!.Value)
            .Must(role => role is UserRoleCode.HotelManager or UserRoleCode.Receptionist or
                UserRoleCode.HousekeepingStaff or UserRoleCode.MaintenanceStaff)
            .When(request => request.Role.HasValue)
            .WithMessage("The selected hotel role is invalid.");
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
            .Must(status => status is RoomOperationalStatus.Available or RoomOperationalStatus.Inactive)
            .WithMessage("Initial status must be Available or Inactive.");
    }
}

internal sealed class UpdatePhysicalRoomRequestValidator : AbstractValidator<UpdatePhysicalRoomRequest>
{
    public UpdatePhysicalRoomRequestValidator()
    {
        RuleFor(request => request.RoomNumber).SafeRequiredText(32, "Room number");
        RuleFor(request => request.Status)
            .Must(status => status is RoomOperationalStatus.Available or RoomOperationalStatus.Inactive)
            .WithMessage("Setup status must be Available or Inactive.");
    }
}
