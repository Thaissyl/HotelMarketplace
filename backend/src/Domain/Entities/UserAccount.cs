using HotelMarketplace.Domain.Common;
using HotelMarketplace.Domain.Enums;
using HotelMarketplace.SharedKernel.Exceptions;

namespace HotelMarketplace.Domain.Entities;

public sealed class UserAccount : Entity
{
    private readonly List<UserAccountRole> _roles = new();
    private readonly List<HotelStaffAssignment> _staffAssignments = new();

    private UserAccount()
    {
        Email = string.Empty;
        PasswordHash = string.Empty;
        FullName = string.Empty;
    }

    public UserAccount(Guid id, string email, string passwordHash, string fullName, string? phoneNumber = null)
        : base(id)
    {
        Email = Guard.NotBlank(email, nameof(Email), 256).ToLowerInvariant();
        PasswordHash = Guard.NotBlank(passwordHash, nameof(PasswordHash), 512);
        FullName = Guard.NotBlank(fullName, nameof(FullName), 200);
        PhoneNumber = Guard.Optional(phoneNumber, nameof(PhoneNumber), 32);
        Status = AccountStatus.Active;
        IsSystemAccount = false;
        CreatedAtUtc = DateTime.UtcNow;
    }

    public string Email { get; private set; }

    public string? PhoneNumber { get; private set; }

    public string PasswordHash { get; private set; }

    public string FullName { get; private set; }

    public AccountStatus Status { get; private set; }

    public bool IsSystemAccount { get; private set; }

    public DateTime CreatedAtUtc { get; private set; }

    public IReadOnlyCollection<UserAccountRole> Roles => _roles;

    public IReadOnlyCollection<HotelStaffAssignment> StaffAssignments => _staffAssignments;

    public void Suspend()
    {
        EnsureInteractiveAccount();

        if (Status == AccountStatus.Suspended)
        {
            return;
        }

        Status = AccountStatus.Suspended;
    }

    public void Reactivate()
    {
        EnsureInteractiveAccount();

        if (Status == AccountStatus.Active)
        {
            return;
        }

        Status = AccountStatus.Active;
    }

    public void UpdateProfile(string fullName, string? phoneNumber)
    {
        EnsureInteractiveAccount();
        FullName = Guard.NotBlank(fullName, nameof(FullName), 200);
        PhoneNumber = Guard.Optional(phoneNumber, nameof(PhoneNumber), 32);
    }

    public void ChangePasswordHash(string passwordHash)
    {
        EnsureInteractiveAccount();
        PasswordHash = Guard.NotBlank(passwordHash, nameof(PasswordHash), 512);
    }

    private void EnsureInteractiveAccount()
    {
        if (IsSystemAccount)
        {
            throw new DomainException(
                "UserAccount.SystemAccountMutationForbidden",
                "System accounts cannot be modified through interactive account operations.");
        }
    }
}
