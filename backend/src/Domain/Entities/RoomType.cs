using HotelMarketplace.Domain.Common;
using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Domain.Entities;

public sealed class RoomType : Entity, IHotelScopedEntity
{
    private RoomType()
    {
        Name = string.Empty;
    }

    public RoomType(Guid id, Guid hotelId, string name, int adultCapacity, int childCapacity, decimal basePricePerNight, string? description = null)
        : base(id)
    {
        Guard.NotEmpty(hotelId, nameof(HotelId));
        Guard.GreaterThanZero(adultCapacity, nameof(AdultCapacity));
        Guard.NonNegative(basePricePerNight, nameof(BasePricePerNight));
        if (childCapacity < 0)
        {
            throw new SharedKernel.Exceptions.DomainException("RoomType.InvalidChildCapacity", "Child capacity cannot be negative.");
        }

        HotelId = hotelId;
        Name = Guard.NotBlank(name, nameof(Name), 160);
        AdultCapacity = adultCapacity;
        ChildCapacity = childCapacity;
        BasePricePerNight = basePricePerNight;
        Description = Guard.Optional(description, nameof(Description), 1000);
        Status = RecordStatus.Active;
    }

    public Guid HotelId { get; private set; }

    public string Name { get; private set; }

    public int AdultCapacity { get; private set; }

    public int ChildCapacity { get; private set; }

    public decimal BasePricePerNight { get; private set; }

    public string? Description { get; private set; }

    public RecordStatus Status { get; private set; }

    public void UpdateDetails(
        string name,
        int adultCapacity,
        int childCapacity,
        decimal basePricePerNight,
        string? description)
    {
        Guard.GreaterThanZero(adultCapacity, nameof(AdultCapacity));
        Guard.NonNegative(basePricePerNight, nameof(BasePricePerNight));

        if (childCapacity < 0)
        {
            throw new SharedKernel.Exceptions.DomainException("RoomType.InvalidChildCapacity", "Child capacity cannot be negative.");
        }

        Name = Guard.NotBlank(name, nameof(Name), 160);
        AdultCapacity = adultCapacity;
        ChildCapacity = childCapacity;
        BasePricePerNight = basePricePerNight;
        Description = Guard.Optional(description, nameof(Description), 1000);
    }

    public void Deactivate()
    {
        Status = RecordStatus.Inactive;
    }
}
