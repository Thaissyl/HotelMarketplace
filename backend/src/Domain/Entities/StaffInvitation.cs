using HotelMarketplace.Domain.Common;
using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Domain.Entities;

public sealed class StaffInvitation : Entity, IHotelScopedEntity
{
    private StaffInvitation()
    {
        Email = string.Empty;
    }

    public StaffInvitation(Guid id, Guid hotelId, Guid roleId, string email, Guid invitedByUserAccountId, DateTime expiresAtUtc)
        : base(id)
    {
        Guard.NotEmpty(hotelId, nameof(HotelId));
        Guard.NotEmpty(roleId, nameof(RoleId));
        Guard.NotEmpty(invitedByUserAccountId, nameof(InvitedByUserAccountId));
        if (expiresAtUtc <= DateTime.UtcNow)
        {
            throw new SharedKernel.Exceptions.DomainException("StaffInvitation.InvalidExpiration", "Invitation expiration must be in the future.");
        }

        HotelId = hotelId;
        RoleId = roleId;
        Email = Guard.NotBlank(email, nameof(Email), 256).ToLowerInvariant();
        InvitedByUserAccountId = invitedByUserAccountId;
        Status = RecordStatus.Active;
        InvitedAtUtc = DateTime.UtcNow;
        ExpiresAtUtc = expiresAtUtc;
    }

    public Guid HotelId { get; private set; }

    public Guid RoleId { get; private set; }

    public string Email { get; private set; }

    public Guid InvitedByUserAccountId { get; private set; }

    public RecordStatus Status { get; private set; }

    public DateTime InvitedAtUtc { get; private set; }

    public DateTime ExpiresAtUtc { get; private set; }
}
