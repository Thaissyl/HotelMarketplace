using HotelMarketplace.Domain.Common;
using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Domain.Entities;

public sealed class HotelImage : Entity, IHotelScopedEntity
{
    private HotelImage()
    {
        ImageUrl = string.Empty;
    }

    public HotelImage(Guid id, Guid hotelId, string imageUrl, int displayOrder)
        : base(id)
    {
        Guard.NotEmpty(hotelId, nameof(HotelId));
        HotelId = hotelId;
        ImageUrl = Guard.NotBlank(imageUrl, nameof(ImageUrl), 1000);
        DisplayOrder = displayOrder;
        Status = RecordStatus.Active;
    }

    public Guid HotelId { get; private set; }

    public string ImageUrl { get; private set; }

    public int DisplayOrder { get; private set; }

    public RecordStatus Status { get; private set; }
}
