using HotelMarketplace.Domain.Entities;

namespace HotelMarketplace.Application.CustomerAccount;

public interface ICustomerAccountRepository
{
    Task<UserAccount?> GetUserAccountAsync(Guid userId, CancellationToken cancellationToken);

    Task<bool> PhoneNumberExistsForAnotherUserAsync(Guid userId, string phoneNumber, CancellationToken cancellationToken);

    Task SaveChangesAsync(CancellationToken cancellationToken);
}
