using FluentValidation;
using FluentValidation.Results;
using HotelMarketplace.Application.Common.Validation;
using HotelMarketplace.Application.Security;
using HotelMarketplace.Domain.Entities;
using HotelMarketplace.Domain.Enums;
using HotelMarketplace.SharedKernel.Results;

namespace HotelMarketplace.Application.Authentication;

internal sealed class AuthService : IAuthService
{
    private readonly IAuthUserRepository _authUserRepository;
    private readonly IPasswordHasher _passwordHasher;
    private readonly IJwtTokenGenerator _jwtTokenGenerator;
    private readonly IValidator<RegisterRequest> _registerValidator;
    private readonly IValidator<LoginRequest> _loginValidator;

    public AuthService(
        IAuthUserRepository authUserRepository,
        IPasswordHasher passwordHasher,
        IJwtTokenGenerator jwtTokenGenerator,
        IValidator<RegisterRequest> registerValidator,
        IValidator<LoginRequest> loginValidator)
    {
        _authUserRepository = authUserRepository;
        _passwordHasher = passwordHasher;
        _jwtTokenGenerator = jwtTokenGenerator;
        _registerValidator = registerValidator;
        _loginValidator = loginValidator;
    }

    public async Task<Result<AuthResponse>> RegisterAsync(RegisterRequest request, CancellationToken cancellationToken)
    {
        ValidationResult validationResult = await _registerValidator.ValidateAsync(request, cancellationToken);
        if (!validationResult.IsValid)
        {
            return Result.Failure<AuthResponse>(
                ValidationErrorFormatter.ToResultError("Auth.InvalidRegistrationRequest", validationResult));
        }

        string normalizedEmail = NormalizeEmail(request.Email);

        if (request.Role is not UserRoleCode.Customer and not UserRoleCode.PropertyOwner)
        {
            return Result.Failure<AuthResponse>(AuthenticationErrors.InvalidRegistrationRole);
        }

        if (await _authUserRepository.EmailExistsAsync(normalizedEmail, cancellationToken))
        {
            return Result.Failure<AuthResponse>(AuthenticationErrors.DuplicateEmail);
        }

        if (!string.IsNullOrWhiteSpace(request.PhoneNumber) &&
            await _authUserRepository.PhoneNumberExistsAsync(request.PhoneNumber.Trim(), cancellationToken))
        {
            return Result.Failure<AuthResponse>(AuthenticationErrors.DuplicatePhoneNumber);
        }

        UserRole? role = await _authUserRepository.GetRoleAsync(request.Role, cancellationToken);

        if (role is null)
        {
            return Result.Failure<AuthResponse>(AuthenticationErrors.InvalidRegistrationRole);
        }

        string passwordHash = _passwordHasher.HashPassword(request.Password);
        UserAccount userAccount = new(Guid.NewGuid(), normalizedEmail, passwordHash, request.FullName, request.PhoneNumber);

        await _authUserRepository.AddUserWithRoleAsync(userAccount, role.Id, cancellationToken);

        CurrentUser currentUser = new(
            userAccount.Id,
            userAccount.Email,
            new[] { request.Role },
            Array.Empty<Guid>(),
            Array.Empty<HotelRoleAccess>());
        GeneratedJwtToken token = _jwtTokenGenerator.Generate(currentUser);

        return new AuthResponse(
            userAccount.Id,
            userAccount.Email,
            currentUser.Roles,
            currentUser.HotelIds,
            token.AccessToken,
            token.ExpiresAtUtc);
    }

    public async Task<Result<AuthResponse>> LoginAsync(LoginRequest request, CancellationToken cancellationToken)
    {
        ValidationResult validationResult = await _loginValidator.ValidateAsync(request, cancellationToken);
        if (!validationResult.IsValid)
        {
            return Result.Failure<AuthResponse>(
                ValidationErrorFormatter.ToResultError("Auth.InvalidLoginRequest", validationResult));
        }

        string normalizedIdentifier = NormalizeLoginIdentifier(request.Email);
        AuthUserSnapshot? user = await _authUserRepository.GetAuthUserByIdentifierAsync(
            normalizedIdentifier,
            cancellationToken);

        if (user is null || user.IsSystemAccount || !_passwordHasher.VerifyPassword(request.Password, user.PasswordHash))
        {
            return Result.Failure<AuthResponse>(AuthenticationErrors.InvalidCredentials);
        }

        if (user.Status != AccountStatus.Active)
        {
            return Result.Failure<AuthResponse>(AuthenticationErrors.InactiveAccount);
        }

        CurrentUser currentUser = new(
            user.UserId,
            user.Email,
            user.Roles,
            user.HotelIds,
            user.HotelRoleAccesses);
        GeneratedJwtToken token = _jwtTokenGenerator.Generate(currentUser);

        return new AuthResponse(
            user.UserId,
            user.Email,
            user.Roles,
            user.HotelIds,
            token.AccessToken,
            token.ExpiresAtUtc);
    }

    private static string NormalizeEmail(string email)
    {
        return email.Trim().ToLowerInvariant();
    }

    private static string NormalizeLoginIdentifier(string identifier)
    {
        string normalizedIdentifier = identifier.Trim();
        return normalizedIdentifier.Contains('@')
            ? normalizedIdentifier.ToLowerInvariant()
            : normalizedIdentifier;
    }
}
