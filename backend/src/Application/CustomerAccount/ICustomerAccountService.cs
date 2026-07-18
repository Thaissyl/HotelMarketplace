using HotelMarketplace.Application.CustomerAccount.Dtos;
using HotelMarketplace.Application.CustomerAccount.Requests;
using HotelMarketplace.SharedKernel.Results;

namespace HotelMarketplace.Application.CustomerAccount;

public interface ICustomerAccountService
{
    Task<Result<CustomerProfileDto>> GetProfileAsync(CancellationToken cancellationToken);

    Task<Result<CustomerProfileDto>> UpdateProfileAsync(UpdateCustomerProfileRequest request, CancellationToken cancellationToken);

    Task<Result> ChangePasswordAsync(ChangeCustomerPasswordRequest request, CancellationToken cancellationToken);
}
