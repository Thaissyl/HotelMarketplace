using FluentValidation;
using FluentValidation.Results;
using HotelMarketplace.Application.Authentication;
using HotelMarketplace.Application.Common.Validation;
using HotelMarketplace.Application.CustomerAccount.Dtos;
using HotelMarketplace.Application.CustomerAccount.Requests;
using HotelMarketplace.Application.Security;
using HotelMarketplace.Domain.Entities;
using HotelMarketplace.Domain.Enums;
using HotelMarketplace.SharedKernel.Results;

namespace HotelMarketplace.Application.CustomerAccount;

internal sealed class CustomerAccountService : ICustomerAccountService
{
    private readonly ICustomerAccountRepository _repository;
    private readonly ICurrentUserService _currentUserService;
    private readonly IPasswordHasher _passwordHasher;
    private readonly IValidator<UpdateCustomerProfileRequest> _profileValidator;
    private readonly IValidator<ChangeCustomerPasswordRequest> _passwordValidator;

    public CustomerAccountService(
        ICustomerAccountRepository repository,
        ICurrentUserService currentUserService,
        IPasswordHasher passwordHasher,
        IValidator<UpdateCustomerProfileRequest> profileValidator,
        IValidator<ChangeCustomerPasswordRequest> passwordValidator)
    {
        _repository = repository;
        _currentUserService = currentUserService;
        _passwordHasher = passwordHasher;
        _profileValidator = profileValidator;
        _passwordValidator = passwordValidator;
    }

    public async Task<Result<CustomerProfileDto>> GetProfileAsync(CancellationToken cancellationToken)
    {
        Result<UserAccount> userResult = await GetAuthorizedUserAsync(cancellationToken);
        return userResult.IsFailure
            ? Result.Failure<CustomerProfileDto>(userResult.Error)
            : Result.Success(ToDto(userResult.Value));
    }

    public async Task<Result<CustomerProfileDto>> UpdateProfileAsync(
        UpdateCustomerProfileRequest request,
        CancellationToken cancellationToken)
    {
        Result<UserAccount> userResult = await GetAuthorizedUserAsync(cancellationToken);
        if (userResult.IsFailure)
        {
            return Result.Failure<CustomerProfileDto>(userResult.Error);
        }

        ValidationResult validationResult = await _profileValidator.ValidateAsync(request, cancellationToken);
        if (!validationResult.IsValid)
        {
            return Result.Failure<CustomerProfileDto>(
                ValidationErrorFormatter.ToResultError("CustomerAccount.InvalidProfile", validationResult));
        }

        string? phoneNumber = string.IsNullOrWhiteSpace(request.PhoneNumber)
            ? null
            : request.PhoneNumber.Trim();

        if (phoneNumber is not null &&
            await _repository.PhoneNumberExistsForAnotherUserAsync(userResult.Value.Id, phoneNumber, cancellationToken))
        {
            return Result.Failure<CustomerProfileDto>(CustomerAccountErrors.DuplicatePhoneNumber);
        }

        userResult.Value.UpdateProfile(request.FullName.Trim(), phoneNumber);
        await _repository.SaveChangesAsync(cancellationToken);

        return Result.Success(ToDto(userResult.Value));
    }

    public async Task<Result> ChangePasswordAsync(
        ChangeCustomerPasswordRequest request,
        CancellationToken cancellationToken)
    {
        Result<UserAccount> userResult = await GetAuthorizedUserAsync(cancellationToken);
        if (userResult.IsFailure)
        {
            return Result.Failure(userResult.Error);
        }

        ValidationResult validationResult = await _passwordValidator.ValidateAsync(request, cancellationToken);
        if (!validationResult.IsValid)
        {
            return Result.Failure(
                ValidationErrorFormatter.ToResultError("CustomerAccount.InvalidPasswordChange", validationResult));
        }

        if (!_passwordHasher.VerifyPassword(request.CurrentPassword, userResult.Value.PasswordHash))
        {
            return Result.Failure(CustomerAccountErrors.InvalidCurrentPassword);
        }

        userResult.Value.ChangePasswordHash(_passwordHasher.HashPassword(request.NewPassword));
        await _repository.SaveChangesAsync(cancellationToken);

        return Result.Success();
    }

    private async Task<Result<UserAccount>> GetAuthorizedUserAsync(CancellationToken cancellationToken)
    {
        if (_currentUserService.UserId is null ||
            !_currentUserService.Roles.Any(role => role is UserRoleCode.Customer or UserRoleCode.PlatformAdministrator))
        {
            return Result.Failure<UserAccount>(CustomerAccountErrors.Forbidden);
        }

        UserAccount? user = await _repository.GetUserAccountAsync(_currentUserService.UserId.Value, cancellationToken);

        return user is null
            ? Result.Failure<UserAccount>(CustomerAccountErrors.UserNotFound)
            : Result.Success(user);
    }

    private static CustomerProfileDto ToDto(UserAccount user)
    {
        return new CustomerProfileDto(
            user.Id,
            user.Email,
            user.FullName,
            user.PhoneNumber);
    }
}
