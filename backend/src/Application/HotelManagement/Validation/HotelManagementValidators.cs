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

internal sealed class UpdateHotelContentRequestValidator : AbstractValidator<UpdateHotelContentRequest>
{
    public UpdateHotelContentRequestValidator()
    {
        RuleFor(request => request.Images).NotNull().Must(images => images is not null && images.Count <= 20)
            .WithMessage("A hotel gallery can contain at most 20 images.");
        RuleForEach(request => request.Images).ChildRules(image =>
        {
            image.RuleFor(value => value.ImageUrl)
                .NotEmpty()
                .MaximumLength(1000)
                .Must(value => Uri.TryCreate(value, UriKind.Absolute, out Uri? uri) &&
                    (uri.Scheme == Uri.UriSchemeHttps || uri.Scheme == Uri.UriSchemeHttp))
                .WithMessage("Image URL must be an absolute HTTP or HTTPS URL.");
            image.RuleFor(value => value.DisplayOrder).InclusiveBetween(0, 999);
        });
        RuleFor(request => request.Images)
            .Must(images => images is not null && images.Select(image => image.DisplayOrder).Distinct().Count() == images.Count)
            .WithMessage("Image display order must be unique.");

        RuleFor(request => request.Amenities).NotNull().Must(amenities => amenities is not null && amenities.Count <= 50)
            .WithMessage("A hotel can contain at most 50 amenities.");
        RuleForEach(request => request.Amenities).ChildRules(amenity =>
        {
            amenity.RuleFor(value => value.Code).Matches("^[A-Za-z0-9_-]+$").MaximumLength(64);
            amenity.RuleFor(value => value.Name).SafeRequiredText(128, "Amenity name");
            amenity.RuleFor(value => value.Type).SafeRequiredText(64, "Amenity type");
        });
        RuleFor(request => request.Amenities)
            .Must(amenities => amenities is not null && amenities.All(amenity => amenity is not null && amenity.Code is not null) &&
                amenities.Select(amenity => amenity.Code.Trim().ToUpperInvariant()).Distinct().Count() == amenities.Count)
            .WithMessage("Amenity codes must be unique.");

        When(request => request.CancellationPolicy is not null, () =>
        {
            RuleFor(request => request.CancellationPolicy!.Name).SafeRequiredText(128, "Policy name");
            RuleFor(request => request.CancellationPolicy!.FreeCancellationHours).InclusiveBetween(0, 8760);
            RuleFor(request => request.CancellationPolicy!.RefundPercentage).InclusiveBetween(0, 100);
            RuleFor(request => request.CancellationPolicy!.Description).SafeOptionalText(1000, "Policy description");
        });
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
        RuleFor(request => request.Facilities).SafeOptionalText(2000, "Facilities");
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
        RuleFor(request => request.Facilities).SafeOptionalText(2000, "Facilities");
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
        RuleFor(request => request.Floor).SafeOptionalText(20, "Floor");
        RuleFor(request => request.Notes).SafeOptionalText(500, "Room notes");
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
        RuleFor(request => request.Floor).SafeOptionalText(20, "Floor");
        RuleFor(request => request.Notes).SafeOptionalText(500, "Room notes");
    }
}
