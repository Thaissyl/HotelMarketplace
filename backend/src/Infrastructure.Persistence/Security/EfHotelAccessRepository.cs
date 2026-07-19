using HotelMarketplace.Application.Security;
using HotelMarketplace.Domain.Enums;
using Microsoft.EntityFrameworkCore;

namespace HotelMarketplace.Infrastructure.Persistence.Security;

internal sealed class EfHotelAccessRepository : IHotelAccessRepository
{
    private readonly HotelMarketplaceDbContext _dbContext;

    public EfHotelAccessRepository(HotelMarketplaceDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    public async Task<IReadOnlyCollection<HotelRoleAccess>> GetActiveAccessesAsync(
        Guid userAccountId,
        CancellationToken cancellationToken)
    {
        bool userIsActive = await IsActiveUserAsync(userAccountId, cancellationToken);
        if (!userIsActive)
        {
            return Array.Empty<HotelRoleAccess>();
        }

        var assignmentRows = await (
            from assignment in _dbContext.HotelStaffAssignments.IgnoreQueryFilters().AsNoTracking()
            join role in _dbContext.UserRoles.IgnoreQueryFilters().AsNoTracking()
                on assignment.RoleId equals role.Id
            where assignment.UserAccountId == userAccountId && assignment.IsActive
            select new { assignment.HotelId, role.Code })
            .ToListAsync(cancellationToken);

        HotelRoleAccess[] assignmentAccesses = assignmentRows
            .Select(row => Enum.TryParse(row.Code, ignoreCase: true, out UserRoleCode role)
                ? new HotelRoleAccess(row.HotelId, role)
                : null)
            .Where(access => access is not null)
            .Select(access => access!)
            .ToArray();

        Guid[] ownedHotelIds = await _dbContext.HotelProperties
            .IgnoreQueryFilters()
            .AsNoTracking()
            .Where(hotel => hotel.OwnerUserAccountId == userAccountId)
            .Select(hotel => hotel.Id)
            .ToArrayAsync(cancellationToken);

        return assignmentAccesses
            .Concat(ownedHotelIds.Select(hotelId => new HotelRoleAccess(hotelId, UserRoleCode.PropertyOwner)))
            .Distinct()
            .ToArray();
    }

    public async Task<bool> HasActiveAccessAsync(
        Guid userAccountId,
        Guid hotelId,
        IReadOnlyCollection<UserRoleCode>? allowedRoles,
        CancellationToken cancellationToken)
    {
        bool userIsActive = await IsActiveUserAsync(userAccountId, cancellationToken);

        if (!userIsActive)
        {
            return false;
        }

        bool propertyOwnerAllowed = allowedRoles is null || allowedRoles.Contains(UserRoleCode.PropertyOwner);
        if (propertyOwnerAllowed)
        {
            bool ownsHotel = await _dbContext.HotelProperties
                .IgnoreQueryFilters()
                .AsNoTracking()
                .AnyAsync(
                    hotel => hotel.Id == hotelId && hotel.OwnerUserAccountId == userAccountId,
                    cancellationToken);

            if (ownsHotel)
            {
                return true;
            }
        }

        IQueryable<string> activeAssignmentRoleCodes =
            from assignment in _dbContext.HotelStaffAssignments.IgnoreQueryFilters().AsNoTracking()
            join role in _dbContext.UserRoles.IgnoreQueryFilters().AsNoTracking()
                on assignment.RoleId equals role.Id
            where assignment.UserAccountId == userAccountId &&
                assignment.HotelId == hotelId &&
                assignment.IsActive
            select role.Code;

        if (allowedRoles is null)
        {
            return await activeAssignmentRoleCodes.AnyAsync(cancellationToken);
        }

        string[] allowedRoleCodes = allowedRoles
            .Select(role => role.ToString().ToUpperInvariant())
            .Distinct()
            .ToArray();

        if (allowedRoleCodes.Length == 0)
        {
            return false;
        }

        string[] assignedRoleCodes = await activeAssignmentRoleCodes.ToArrayAsync(cancellationToken);
        return assignedRoleCodes.Any(allowedRoleCodes.Contains);
    }

    private Task<bool> IsActiveUserAsync(Guid userAccountId, CancellationToken cancellationToken)
    {
        return _dbContext.UserAccounts
            .IgnoreQueryFilters()
            .AsNoTracking()
            .AnyAsync(
                user => user.Id == userAccountId && user.Status == AccountStatus.Active,
                cancellationToken);
    }
}
