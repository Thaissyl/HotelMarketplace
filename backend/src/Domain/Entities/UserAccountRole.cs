using HotelMarketplace.Domain.Common;

namespace HotelMarketplace.Domain.Entities;

public sealed class UserAccountRole : Entity
{
    private UserAccountRole()
    {
    }

    public UserAccountRole(Guid id, Guid userAccountId, Guid roleId)
        : base(id)
    {
        Guard.NotEmpty(userAccountId, nameof(UserAccountId));
        Guard.NotEmpty(roleId, nameof(RoleId));
        UserAccountId = userAccountId;
        RoleId = roleId;
        IsActive = true;
        AssignedAtUtc = DateTime.UtcNow;
    }

    public Guid UserAccountId { get; private set; }

    public Guid RoleId { get; private set; }

    public bool IsActive { get; private set; }

    public DateTime AssignedAtUtc { get; private set; }
}
