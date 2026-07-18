using HotelMarketplace.Application.CustomerAccount;
using HotelMarketplace.Application.CustomerAccount.Dtos;
using HotelMarketplace.Application.CustomerAccount.Requests;
using HotelMarketplace.Domain.Enums;
using HotelMarketplace.SharedKernel.Results;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace HotelMarketplace.Presentation.Api.Controllers;

[ApiController]
[Route("api/customer/account")]
[Authorize(Roles = nameof(UserRoleCode.Customer) + "," + nameof(UserRoleCode.PlatformAdministrator))]
public sealed class CustomerAccountController : ControllerBase
{
    private readonly ICustomerAccountService _customerAccountService;

    public CustomerAccountController(ICustomerAccountService customerAccountService)
    {
        _customerAccountService = customerAccountService;
    }

    [HttpGet("profile")]
    [ProducesResponseType(typeof(CustomerProfileDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetProfile(CancellationToken cancellationToken)
    {
        Result<CustomerProfileDto> result = await _customerAccountService.GetProfileAsync(cancellationToken);

        return result.IsFailure ? ToProblem(result.Error) : Ok(result.Value);
    }

    [HttpPut("profile")]
    [ProducesResponseType(typeof(CustomerProfileDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status409Conflict)]
    public async Task<IActionResult> UpdateProfile(
        UpdateCustomerProfileRequest request,
        CancellationToken cancellationToken)
    {
        Result<CustomerProfileDto> result = await _customerAccountService.UpdateProfileAsync(request, cancellationToken);

        return result.IsFailure ? ToProblem(result.Error) : Ok(result.Value);
    }

    [HttpPost("change-password")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status409Conflict)]
    public async Task<IActionResult> ChangePassword(
        ChangeCustomerPasswordRequest request,
        CancellationToken cancellationToken)
    {
        Result result = await _customerAccountService.ChangePasswordAsync(request, cancellationToken);

        return result.IsFailure ? ToProblem(result.Error) : NoContent();
    }

    private ObjectResult ToProblem(ResultError error)
    {
        int statusCode = error.Code switch
        {
            "CustomerAccount.Forbidden" => StatusCodes.Status403Forbidden,
            "CustomerAccount.UserNotFound" => StatusCodes.Status404NotFound,
            "CustomerAccount.InvalidCurrentPassword" => StatusCodes.Status409Conflict,
            "CustomerAccount.DuplicatePhoneNumber" => StatusCodes.Status409Conflict,
            _ => StatusCodes.Status400BadRequest
        };

        return this.ToProblemResult(error, statusCode);
    }
}
