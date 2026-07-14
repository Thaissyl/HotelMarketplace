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

    public AuthService(
        IAuthUserRepository authUserRepository,
        IPasswordHasher passwordHasher,
        IJwtTokenGenerator jwtTokenGenerator)
    {
        _authUserRepository = authUserRepository;
        _passwordHasher = passwordHasher;
        _jwtTokenGenerator = jwtTokenGenerator;
    }

    public async Task<Result<AuthResponse>> RegisterAsync(RegisterRequest request, CancellationToken cancellationToken)
    {
        string normalizedEmail = NormalizeEmail(request.Email);

        if (request.Role is not UserRoleCode.Customer and not UserRoleCode.PropertyOwner)
        {
            return Result.Failure<AuthResponse>(AuthenticationErrors.InvalidRegistrationRole);
        }

        if (await _authUserRepository.EmailExistsAsync(normalizedEmail, cancellationToken))
        {
            return Result.Failure<AuthResponse>(AuthenticationErrors.DuplicateEmail);
        }

        UserRole? role = await _authUserRepository.GetRoleAsync(request.Role, cancellationToken);

        if (role is null)
        {
            return Result.Failure<AuthResponse>(AuthenticationErrors.InvalidRegistrationRole);
        }

        string passwordHash = _passwordHasher.HashPassword(request.Password);
        UserAccount userAccount = new(Guid.NewGuid(), normalizedEmail, passwordHash, request.FullName, request.PhoneNumber);

        await _authUserRepository.AddUserWithRoleAsync(userAccount, role.Id, cancellationToken);

        CurrentUser currentUser = new(userAccount.Id, userAccount.Email, new[] { request.Role }, Array.Empty<Guid>());
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
        string normalizedEmail = NormalizeEmail(request.Email);
        AuthUserSnapshot? user = await _authUserRepository.GetAuthUserByEmailAsync(normalizedEmail, cancellationToken);

        if (user is null || !_passwordHasher.VerifyPassword(request.Password, user.PasswordHash))
        {
            return Result.Failure<AuthResponse>(AuthenticationErrors.InvalidCredentials);
        }

        if (user.Status != AccountStatus.Active)
        {
            return Result.Failure<AuthResponse>(AuthenticationErrors.InactiveAccount);
        }

        CurrentUser currentUser = new(user.UserId, user.Email, user.Roles, user.HotelIds);
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
}
