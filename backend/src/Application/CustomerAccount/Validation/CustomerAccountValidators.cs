using FluentValidation;
using HotelMarketplace.Application.Common.Validation;

namespace HotelMarketplace.Application.CustomerAccount.Validation;

internal sealed class UpdateCustomerProfileRequestValidator : AbstractValidator<Requests.UpdateCustomerProfileRequest>
{
    public UpdateCustomerProfileRequestValidator()
    {
        RuleFor(request => request.FullName)
            .SafeRequiredText(200, "Full name")
            .MinimumLength(2)
            .Must(fullName => !string.Equals(fullName?.Trim(), "string", StringComparison.OrdinalIgnoreCase))
            .WithMessage("Full name must be a real name.");

        RuleFor(request => request.PhoneNumber)
            .OptionalTenDigitPhone("Phone number");
    }
}

internal sealed class ChangeCustomerPasswordRequestValidator : AbstractValidator<Requests.ChangeCustomerPasswordRequest>
{
    public ChangeCustomerPasswordRequestValidator()
    {
        RuleFor(request => request.CurrentPassword)
            .NotEmpty()
            .MaximumLength(100);

        RuleFor(request => request.NewPassword)
            .NotEmpty()
            .MinimumLength(8)
            .MaximumLength(100)
            .Matches("[A-Z]").WithMessage("Password must contain at least one uppercase letter.")
            .Matches("[a-z]").WithMessage("Password must contain at least one lowercase letter.")
            .Matches("[0-9]").WithMessage("Password must contain at least one digit.")
            .Must(password => !string.Equals(password?.Trim(), "string", StringComparison.OrdinalIgnoreCase))
            .WithMessage("Password must not use the Swagger placeholder value.");

        RuleFor(request => request.ConfirmNewPassword)
            .Equal(request => request.NewPassword)
            .WithMessage("New password confirmation does not match.");
    }
}
