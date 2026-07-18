using FluentValidation;
using HotelMarketplace.Application.Common.Validation;
using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.Authentication.Validation;

internal sealed class RegisterRequestValidator : AbstractValidator<RegisterRequest>
{
    public RegisterRequestValidator()
    {
        RuleFor(request => request.Email)
            .NotEmpty()
            .EmailAddress()
            .MaximumLength(256)
            .Must(email => !string.Equals(email?.Trim(), "string", StringComparison.OrdinalIgnoreCase))
            .WithMessage("Email must be a real email address.");

        RuleFor(request => request.Password)
            .NotEmpty()
            .MinimumLength(8)
            .MaximumLength(100)
            .Matches("[A-Z]").WithMessage("Password must contain at least one uppercase letter.")
            .Matches("[a-z]").WithMessage("Password must contain at least one lowercase letter.")
            .Matches("[0-9]").WithMessage("Password must contain at least one digit.")
            .Must(password => !string.Equals(password?.Trim(), "string", StringComparison.OrdinalIgnoreCase))
            .WithMessage("Password must not use the Swagger placeholder value.");

        RuleFor(request => request.FullName)
            .SafeRequiredText(200, "Full name")
            .MinimumLength(2)
            .Must(fullName => !string.Equals(fullName?.Trim(), "string", StringComparison.OrdinalIgnoreCase))
            .WithMessage("Full name must be a real name.");

        RuleFor(request => request.PhoneNumber)
            .OptionalTenDigitPhone("Phone number");

        RuleFor(request => request.Role)
            .Must(role => role is UserRoleCode.Customer or UserRoleCode.PropertyOwner)
            .WithMessage("Only Customer and PropertyOwner registration is allowed.");
    }
}

internal sealed class LoginRequestValidator : AbstractValidator<LoginRequest>
{
    public LoginRequestValidator()
    {
        RuleFor(request => request.Email)
            .NotEmpty()
            .EmailAddress()
            .MaximumLength(256);

        RuleFor(request => request.Password)
            .NotEmpty()
            .MaximumLength(100);
    }
}
