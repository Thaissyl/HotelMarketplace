using FluentValidation.Results;
using HotelMarketplace.SharedKernel.Results;

namespace HotelMarketplace.Application.Common.Validation;

internal static class ValidationErrorFormatter
{
    public static ResultError ToResultError(string code, ValidationResult validationResult)
    {
        string message = string.Join(
            " ",
            validationResult.Errors
                .Select(error => error.ErrorMessage)
                .Distinct(StringComparer.Ordinal));

        return new ResultError(code, message);
    }
}
