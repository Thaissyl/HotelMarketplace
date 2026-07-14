using HotelMarketplace.Domain.Common;

namespace HotelMarketplace.Domain.Entities;

public sealed class HotelStaffAssignment : Entity, IHotelScopedEntity
{
    private HotelStaffAssignment()
    {
    }

    public HotelStaffAssignment(Guid id, Guid userAccountId, Guid hotelId, Guid roleId, Guid assignedByUserAccountId)
        : base(id)
    {
        Guard.NotEmpty(userAccountId, nameof(UserAccountId));
        Guard.NotEmpty(hotelId, nameof(HotelId));
        Guard.NotEmpty(roleId, nameof(RoleId));
        Guard.NotEmpty(assignedByUserAccountId, nameof(AssignedByUserAccountId));
        UserAccountId = userAccountId;
        HotelId = hotelId;
        RoleId = roleId;
        AssignedByUserAccountId = assignedByUserAccountId;
        IsActive = true;
        AssignedAtUtc = DateTime.UtcNow;
    }

    public Guid UserAccountId { get; private set; }

    public Guid HotelId { get; private set; }

    public Guid RoleId { get; private set; }

    public Guid AssignedByUserAccountId { get; private set; }

    public bool IsActive { get; private set; }

    public DateTime AssignedAtUtc { get; private set; }
}
