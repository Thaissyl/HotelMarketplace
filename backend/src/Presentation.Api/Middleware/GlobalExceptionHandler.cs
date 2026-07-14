using HotelMarketplace.SharedKernel.Exceptions;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;

namespace HotelMarketplace.Presentation.Api.Middleware;

internal sealed class GlobalExceptionHandler : IExceptionHandler
{
    private static readonly Action<ILogger, Exception> LogUnhandledException =
        LoggerMessage.Define(
            LogLevel.Error,
            new EventId(1, nameof(LogUnhandledException)),
            "Unhandled exception occurred.");

    private static readonly Action<ILogger, string, Exception> LogHandledException =
        LoggerMessage.Define<string>(
            LogLevel.Warning,
            new EventId(2, nameof(LogHandledException)),
            "Handled exception occurred with code {ErrorCode}.");

    private readonly IProblemDetailsService _problemDetailsService;
    private readonly ILogger<GlobalExceptionHandler> _logger;

    public GlobalExceptionHandler(
        IProblemDetailsService problemDetailsService,
        ILogger<GlobalExceptionHandler> logger)
    {
        _problemDetailsService = problemDetailsService;
        _logger = logger;
    }

    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext,
        Exception exception,
        CancellationToken cancellationToken)
    {
        ProblemDetails problemDetails = exception switch
        {
            HotelMarketplaceException domainException => CreateProblemDetails(
                httpContext,
                StatusCodes.Status400BadRequest,
                domainException.Code,
                domainException.Message),
            UnauthorizedAccessException => CreateProblemDetails(
                httpContext,
                StatusCodes.Status403Forbidden,
                "Security.Forbidden",
                "The requested operation is not allowed for the current user."),
            _ => CreateProblemDetails(
                httpContext,
                StatusCodes.Status500InternalServerError,
                "Server.UnhandledError",
                "An unexpected server error occurred.")
        };

        if (problemDetails.Status == StatusCodes.Status500InternalServerError)
        {
            LogUnhandledException(_logger, exception);
        }
        else
        {
            LogHandledException(_logger, problemDetails.Extensions["code"]?.ToString() ?? string.Empty, exception);
        }

        httpContext.Response.StatusCode = problemDetails.Status ?? StatusCodes.Status500InternalServerError;

        return await _problemDetailsService.TryWriteAsync(new ProblemDetailsContext
        {
            HttpContext = httpContext,
            Exception = exception,
            ProblemDetails = problemDetails
        });
    }

    private static ProblemDetails CreateProblemDetails(
        HttpContext httpContext,
        int statusCode,
        string code,
        string detail)
    {
        ProblemDetails problemDetails = new()
        {
            Status = statusCode,
            Title = GetTitle(statusCode),
            Detail = detail,
            Instance = httpContext.Request.Path
        };

        problemDetails.Extensions["code"] = code;

        return problemDetails;
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
            StatusCodes.Status500InternalServerError => "Internal Server Error",
            _ => "HTTP Error"
        };
    }
}
