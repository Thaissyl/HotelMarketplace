using HotelMarketplace.Application.FrontDesk.Dtos;
using HotelMarketplace.Application.FrontDesk.Requests;
using HotelMarketplace.Domain.Entities;
using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.FrontDesk;

public interface IFrontDeskRepository
{
    Task<IReadOnlyCollection<PhysicalRoom>> GetPhysicalRoomsAsync(
        Guid hotelId,
        Guid? roomTypeId,
        CancellationToken cancellationToken);

    Task<IReadOnlyCollection<FrontDeskBookingSummaryDto>> GetBookingsAsync(
        Guid hotelId,
        BookingStatus? status,
        DateOnly? fromDate,
        DateOnly? toDate,
        CancellationToken cancellationToken);

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

    Task<FrontDeskPersistenceResult> MarkBookingNoShowAsync(
        Guid hotelId,
        Guid bookingId,
        Guid actorUserAccountId,
        MarkBookingNoShowRequest request,
        CancellationToken cancellationToken);
}
