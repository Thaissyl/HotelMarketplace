using HotelMarketplace.Application.CustomerAccount;
using HotelMarketplace.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace HotelMarketplace.Infrastructure.Persistence.CustomerAccount;

internal sealed class EfCustomerAccountRepository : ICustomerAccountRepository
{
    private readonly HotelMarketplaceDbContext _dbContext;

    public EfCustomerAccountRepository(HotelMarketplaceDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    public Task<UserAccount?> GetUserAccountAsync(Guid userId, CancellationToken cancellationToken)
    {
        return _dbContext.UserAccounts
            .IgnoreQueryFilters()
            .FirstOrDefaultAsync(user => user.Id == userId, cancellationToken);
    }

    public Task<bool> PhoneNumberExistsForAnotherUserAsync(
        Guid userId,
        string phoneNumber,
        CancellationToken cancellationToken)
    {
        return _dbContext.UserAccounts
            .IgnoreQueryFilters()
            .AsNoTracking()
            .AnyAsync(user => user.Id != userId && user.PhoneNumber == phoneNumber, cancellationToken);
    }

    public Task SaveChangesAsync(CancellationToken cancellationToken)
    {
        return _dbContext.SaveChangesAsync(cancellationToken);
    }
}
