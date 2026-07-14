using HotelMarketplace.Application.Authentication;
using HotelMarketplace.SharedKernel.Results;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace HotelMarketplace.Presentation.Api.Controllers;

[ApiController]
[Route("api/auth")]
[AllowAnonymous]
public sealed class AuthController : ControllerBase
{
    private readonly IAuthService _authService;

    public AuthController(IAuthService authService)
    {
        _authService = authService;
    }

    [HttpPost("register")]
    [ProducesResponseType(typeof(AuthResponse), StatusCodes.Status201Created)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status409Conflict)]
    public async Task<IActionResult> Register(RegisterRequest request, CancellationToken cancellationToken)
    {
        Result<AuthResponse> result = await _authService.RegisterAsync(request, cancellationToken);

        if (result.IsFailure)
        {
            return ToProblem(result.Error);
        }

        return CreatedAtAction(nameof(Register), new { userId = result.Value.UserId }, result.Value);
    }

    [HttpPost("login")]
    [ProducesResponseType(typeof(AuthResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> Login(LoginRequest request, CancellationToken cancellationToken)
    {
        Result<AuthResponse> result = await _authService.LoginAsync(request, cancellationToken);

        if (result.IsFailure)
        {
            return ToProblem(result.Error);
        }

        return Ok(result.Value);
    }

    private ObjectResult ToProblem(ResultError error)
    {
        int statusCode = error.Code switch
        {
            "Auth.DuplicateEmail" => StatusCodes.Status409Conflict,
            "Auth.InvalidCredentials" => StatusCodes.Status401Unauthorized,
            "Auth.InactiveAccount" => StatusCodes.Status403Forbidden,
            _ => StatusCodes.Status400BadRequest
        };

        ProblemDetails problemDetails = new()
        {
            Status = statusCode,
            Title = statusCode switch
            {
                StatusCodes.Status401Unauthorized => "Unauthorized",
                StatusCodes.Status403Forbidden => "Forbidden",
                StatusCodes.Status409Conflict => "Conflict",
                _ => "Bad Request"
            },
            Detail = error.Message,
            Instance = HttpContext.Request.Path
        };

        problemDetails.Extensions["code"] = error.Code;

        return StatusCode(statusCode, problemDetails);
    }
}
