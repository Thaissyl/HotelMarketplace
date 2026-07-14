namespace HotelMarketplace.Application.Security;

public interface IHotelAccessAuthorizer
{
    bool HasAccess(Guid hotelId);
}
