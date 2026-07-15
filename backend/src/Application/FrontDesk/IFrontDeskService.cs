using HotelMarketplace.Application.FrontDesk.Dtos;
using HotelMarketplace.Application.HotelManagement.Dtos;
using HotelMarketplace.Application.FrontDesk.Requests;
using HotelMarketplace.SharedKernel.Results;

namespace HotelMarketplace.Application.FrontDesk;

public interface IFrontDeskService
{
    Task<Result<IReadOnlyCollection<PhysicalRoomDto>>> GetPhysicalRoomsAsync(
        Guid hotelId,
        Guid? roomTypeId,
        CancellationToken cancellationToken);

    Task<Result<FrontDeskBookingDto>> CheckInBookingAsync(
        Guid hotelId,
        Guid bookingId,
        CheckInBookingRequest request,
        CancellationToken cancellationToken);

    Task<Result<FrontDeskBookingDto>> CheckOutBookingAsync(
        Guid hotelId,
        Guid bookingId,
        CheckOutBookingRequest request,
        CancellationToken cancellationToken);

    Task<Result<FrontDeskBookingDto>> CreateWalkInBookingAsync(
        Guid hotelId,
        CreateWalkInBookingRequest request,
        CancellationToken cancellationToken);
}
