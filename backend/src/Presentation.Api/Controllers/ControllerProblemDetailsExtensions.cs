using HotelMarketplace.SharedKernel.Results;
using Microsoft.AspNetCore.Mvc;

namespace HotelMarketplace.Presentation.Api.Controllers;

internal static class ControllerProblemDetailsExtensions
{
    public static ObjectResult ToProblemResult(
        this ControllerBase controller,
        ResultError error,
        int statusCode)
    {
        ProblemDetails problemDetails = new()
        {
            Status = statusCode,
            Title = GetTitle(statusCode),
            Detail = error.Message,
            Instance = controller.HttpContext.Request.Path
        };

        problemDetails.Extensions["code"] = error.Code;

        return controller.StatusCode(statusCode, problemDetails);
    }

    private static string GetTitle(int statusCode)
    {
        return statusCode switch
        {
            StatusCodes.Status400BadRequest => "Bad Request",
            StatusCodes.Status401Unauthorized => "Unauthorized",
            StatusCodes.Status403Forbidden => "Forbidden",
            StatusCodes.Status404NotFound => "Not Found",
            StatusCodes.Status409Conflict => "Conflict",
            StatusCodes.Status423Locked => "Locked",
            StatusCodes.Status502BadGateway => "Bad Gateway",
            _ => "HTTP Error"
        };
    }
}
