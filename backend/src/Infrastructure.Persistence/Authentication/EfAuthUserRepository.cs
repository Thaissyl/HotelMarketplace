using HotelMarketplace.Application.Authentication;
using HotelMarketplace.Domain.Entities;
using HotelMarketplace.Domain.Enums;
using Microsoft.EntityFrameworkCore;

namespace HotelMarketplace.Infrastructure.Persistence.Authentication;

internal sealed class EfAuthUserRepository : IAuthUserRepository
{
    private readonly HotelMarketplaceDbContext _dbContext;

    public EfAuthUserRepository(HotelMarketplaceDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    public Task<bool> EmailExistsAsync(string email, CancellationToken cancellationToken)
    {
        return _dbContext.UserAccounts
            .IgnoreQueryFilters()
            .AnyAsync(user => user.Email == email, cancellationToken);
    }

    public Task<bool> PhoneNumberExistsAsync(string phoneNumber, CancellationToken cancellationToken)
    {
        return _dbContext.UserAccounts
            .IgnoreQueryFilters()
            .AnyAsync(user => user.PhoneNumber == phoneNumber, cancellationToken);
    }

    public Task<UserRole?> GetRoleAsync(UserRoleCode roleCode, CancellationToken cancellationToken)
    {
        string roleCodeValue = roleCode.ToString().ToUpperInvariant();

        return _dbContext.UserRoles
            .IgnoreQueryFilters()
            .FirstOrDefaultAsync(role => role.Code == roleCodeValue, cancellationToken);
    }

    public async Task AddUserWithRoleAsync(UserAccount userAccount, Guid roleId, CancellationToken cancellationToken)
    {
        UserAccountRole accountRole = new(Guid.NewGuid(), userAccount.Id, roleId);

        await _dbContext.UserAccounts.AddAsync(userAccount, cancellationToken);
        await _dbContext.UserAccountRoles.AddAsync(accountRole, cancellationToken);
        await _dbContext.SaveChangesAsync(cancellationToken);
    }

    public async Task<AuthUserSnapshot?> GetAuthUserByEmailAsync(string email, CancellationToken cancellationToken)
    {
        UserAccount? user = await _dbContext.UserAccounts
            .IgnoreQueryFilters()
            .AsNoTracking()
            .FirstOrDefaultAsync(account => account.Email == email, cancellationToken);

        if (user is null)
        {
            return null;
        }

        List<string> roleCodes = await _dbContext.UserAccountRoles
            .IgnoreQueryFilters()
            .AsNoTracking()
            .Where(accountRole => accountRole.UserAccountId == user.Id && accountRole.IsActive)
            .Join(
                _dbContext.UserRoles.IgnoreQueryFilters().AsNoTracking(),
                accountRole => accountRole.RoleId,
                role => role.Id,
                (_, role) => role.Code)
            .ToListAsync(cancellationToken);

        List<UserRoleCode> roles = roleCodes
            .Select(ParseRoleCode)
            .Where(role => role.HasValue)
            .Select(role => role!.Value)
            .Distinct()
            .ToList();

        List<Guid> staffHotelIds = await _dbContext.HotelStaffAssignments
            .IgnoreQueryFilters()
            .AsNoTracking()
            .Where(assignment => assignment.UserAccountId == user.Id && assignment.IsActive)
            .Select(assignment => assignment.HotelId)
            .ToListAsync(cancellationToken);

        List<Guid> ownedHotelIds = await _dbContext.HotelProperties
            .IgnoreQueryFilters()
            .AsNoTracking()
            .Where(hotel => hotel.OwnerUserAccountId == user.Id)
            .Select(hotel => hotel.Id)
            .ToListAsync(cancellationToken);

        List<Guid> hotelIds = staffHotelIds
            .Concat(ownedHotelIds)
            .Distinct()
            .ToList();

        return new AuthUserSnapshot(
            user.Id,
            user.Email,
            user.PasswordHash,
            user.Status,
            roles,
            hotelIds);
    }

    private static UserRoleCode? ParseRoleCode(string roleCode)
    {
        return Enum.TryParse(roleCode, ignoreCase: true, out UserRoleCode parsedRole)
            ? parsedRole
            : null;
    }
}
