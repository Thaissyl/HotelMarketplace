using HotelMarketplace.SharedKernel.Exceptions;

namespace HotelMarketplace.Domain.Common;

internal static class Guard
{
    public static string NotBlank(string value, string fieldName, int maxLength)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            throw new DomainException("Domain.RequiredField", $"{fieldName} is required.");
        }

        string trimmed = value.Trim();

        if (trimmed.Length > maxLength)
        {
            throw new DomainException("Domain.FieldTooLong", $"{fieldName} must be {maxLength} characters or fewer.");
        }

        return trimmed;
    }

    public static string? Optional(string? value, string fieldName, int maxLength)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return null;
        }

        string trimmed = value.Trim();

        if (trimmed.Length > maxLength)
        {
            throw new DomainException("Domain.FieldTooLong", $"{fieldName} must be {maxLength} characters or fewer.");
        }

        return trimmed;
    }

    public static void NotEmpty(Guid value, string fieldName)
    {
        if (value == Guid.Empty)
        {
            throw new DomainException("Domain.RequiredIdentifier", $"{fieldName} is required.");
        }
    }

    public static void GreaterThanZero(int value, string fieldName)
    {
        if (value <= 0)
        {
            throw new DomainException("Domain.InvalidQuantity", $"{fieldName} must be greater than zero.");
        }
    }

    public static void NonNegative(decimal value, string fieldName)
    {
        if (value < 0)
        {
            throw new DomainException("Domain.InvalidAmount", $"{fieldName} cannot be negative.");
        }
    }

    public static void DateRange(DateOnly startDate, DateOnly endDate, string code)
    {
        if (endDate <= startDate)
        {
            throw new DomainException(code, "End date must be after start date.");
        }
    }

    public static void Rate(decimal value, string fieldName, decimal maximum)
    {
        if (value < 0 || value > maximum)
        {
            throw new DomainException("Domain.InvalidRate", $"{fieldName} must be between 0 and {maximum}.");
        }
    }
}
