using HotelMarketplace.Domain.Entities;
using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.Authentication;

public interface IAuthUserRepository
{
    Task<bool> EmailExistsAsync(string email, CancellationToken cancellationToken);

    Task<UserRole?> GetRoleAsync(UserRoleCode roleCode, CancellationToken cancellationToken);

    Task AddUserWithRoleAsync(UserAccount userAccount, Guid roleId, CancellationToken cancellationToken);

    Task<AuthUserSnapshot?> GetAuthUserByEmailAsync(string email, CancellationToken cancellationToken);
}
