using HotelMarketplace.Domain.Common;
using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Domain.Entities;

public sealed class Amenity : Entity
{
    private Amenity()
    {
        Code = string.Empty;
        Name = string.Empty;
        Type = string.Empty;
    }

    public Amenity(Guid id, string code, string name, string type)
        : base(id)
    {
        Code = Guard.NotBlank(code, nameof(Code), 64).ToUpperInvariant();
        Name = Guard.NotBlank(name, nameof(Name), 128);
        Type = Guard.NotBlank(type, nameof(Type), 64);
        Status = RecordStatus.Active;
    }

    public string Code { get; private set; }

    public string Name { get; private set; }

    public string Type { get; private set; }

    public RecordStatus Status { get; private set; }

    public void Update(string name, string type)
    {
        Name = Guard.NotBlank(name, nameof(Name), 128);
        Type = Guard.NotBlank(type, nameof(Type), 64);
        Status = RecordStatus.Active;
    }
}
