using HotelMarketplace.Domain.Common;
using HotelMarketplace.Domain.Enums;

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
        CreatedAtUtc = DateTime.UtcNow;
    }

    public string Email { get; private set; }

    public string? PhoneNumber { get; private set; }

    public string PasswordHash { get; private set; }

    public string FullName { get; private set; }

    public AccountStatus Status { get; private set; }

    public DateTime CreatedAtUtc { get; private set; }

    public IReadOnlyCollection<UserAccountRole> Roles => _roles;

    public IReadOnlyCollection<HotelStaffAssignment> StaffAssignments => _staffAssignments;
}
