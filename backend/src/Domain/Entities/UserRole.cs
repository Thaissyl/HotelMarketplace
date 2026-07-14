using HotelMarketplace.Domain.Common;
using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Domain.Entities;

public sealed class UserRole : Entity
{
    private UserRole()
    {
        Code = string.Empty;
        Name = string.Empty;
    }

    public UserRole(Guid id, string code, string name, RoleScope scope)
        : base(id)
    {
        Code = Guard.NotBlank(code, nameof(Code), 64).ToUpperInvariant();
        Name = Guard.NotBlank(name, nameof(Name), 128);
        Scope = scope;
    }

    public string Code { get; private set; }

    public string Name { get; private set; }

    public RoleScope Scope { get; private set; }
}
