using HotelMarketplace.SharedKernel.Results;

namespace HotelMarketplace.Application.Authentication;

public interface IAuthService
{
    Task<Result<AuthResponse>> RegisterAsync(RegisterRequest request, CancellationToken cancellationToken);

    Task<Result<AuthResponse>> LoginAsync(LoginRequest request, CancellationToken cancellationToken);
}
