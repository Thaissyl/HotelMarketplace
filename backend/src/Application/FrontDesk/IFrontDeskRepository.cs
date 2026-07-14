using HotelMarketplace.Application.FrontDesk.Requests;

namespace HotelMarketplace.Application.FrontDesk;

public interface IFrontDeskRepository
{
    Task<FrontDeskPersistenceResult> CheckInBookingAsync(
        Guid hotelId,
        Guid bookingId,
        Guid actorUserAccountId,
        CheckInBookingRequest request,
        CancellationToken cancellationToken);

    Task<FrontDeskPersistenceResult> CheckOutBookingAsync(
        Guid hotelId,
        Guid bookingId,
        Guid actorUserAccountId,
        CheckOutBookingRequest request,
        CancellationToken cancellationToken);

    Task<FrontDeskPersistenceResult> CreateWalkInBookingAsync(
        Guid hotelId,
        Guid actorUserAccountId,
        CreateWalkInBookingRequest request,
        CancellationToken cancellationToken);
}
