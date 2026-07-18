using FluentValidation;
using System.Text.RegularExpressions;

namespace HotelMarketplace.Application.Common.Validation;

internal static class InputValidationRules
{
    private const string TenDigitPhonePattern = "^\\d{10}$";

    public static IRuleBuilderOptions<T, string> SafeRequiredText<T>(
        this IRuleBuilder<T, string> ruleBuilder,
        int maximumLength,
        string fieldName)
    {
        return ruleBuilder
            .NotEmpty()
            .MaximumLength(maximumLength)
            .Must(BeSafePlainText)
            .WithMessage($"{fieldName} cannot contain HTML markup or control characters.");
    }

    public static IRuleBuilderOptions<T, string?> SafeOptionalText<T>(
        this IRuleBuilder<T, string?> ruleBuilder,
        int maximumLength,
        string fieldName)
    {
        return ruleBuilder
            .MaximumLength(maximumLength)
            .Must(value => string.IsNullOrWhiteSpace(value) || BeSafePlainText(value))
            .WithMessage($"{fieldName} cannot contain HTML markup or control characters.");
    }

    public static IRuleBuilderOptions<T, string> TenDigitPhone<T>(
        this IRuleBuilder<T, string> ruleBuilder,
        string fieldName)
    {
        return ruleBuilder
            .NotEmpty()
            .Matches(TenDigitPhonePattern)
            .WithMessage($"{fieldName} must contain exactly 10 digits.");
    }

    public static IRuleBuilderOptions<T, string?> OptionalTenDigitPhone<T>(
        this IRuleBuilder<T, string?> ruleBuilder,
        string fieldName)
    {
        return ruleBuilder
            .Must(value => string.IsNullOrWhiteSpace(value) || Regex.IsMatch(value, TenDigitPhonePattern))
            .WithMessage($"{fieldName} must contain exactly 10 digits.");
    }

    private static bool BeSafePlainText(string? value)
    {
        if (value is null)
        {
            return true;
        }

        foreach (char character in value)
        {
            if (character is '<' or '>')
            {
                return false;
            }

            if (char.IsControl(character) && character is not '\r' and not '\n' and not '\t')
            {
                return false;
            }
        }

        return true;
    }
}
