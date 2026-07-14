namespace HotelMarketplace.Domain.Common;

public interface IHotelScopedEntity
{
    Guid HotelId { get; }
}
