using HotelMarketplace.Domain.Common;

namespace HotelMarketplace.Domain.Entities;

public sealed class Amenity : Entity
{
    private Amenity()
    {
        Code = string.Empty;
        Name = string.Empty;
    }

    public Amenity(Guid id, string code, string name)
        : base(id)
    {
        Code = Guard.NotBlank(code, nameof(Code), 64).ToUpperInvariant();
        Name = Guard.NotBlank(name, nameof(Name), 128);
    }

    public string Code { get; private set; }

    public string Name { get; private set; }
}
