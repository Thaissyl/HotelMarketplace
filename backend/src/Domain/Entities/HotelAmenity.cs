using HotelMarketplace.Domain.Common;

namespace HotelMarketplace.Domain.Entities;

public sealed class HotelAmenity : Entity, IHotelScopedEntity
{
    private HotelAmenity()
    {
    }

    public HotelAmenity(Guid id, Guid hotelId, Guid amenityId)
        : base(id)
    {
        Guard.NotEmpty(hotelId, nameof(HotelId));
        Guard.NotEmpty(amenityId, nameof(AmenityId));
        HotelId = hotelId;
        AmenityId = amenityId;
    }

    public Guid HotelId { get; private set; }

    public Guid AmenityId { get; private set; }
}
