using HotelMarketplace.Application.Availability.Dtos;
using HotelMarketplace.Application.Availability.Requests;
using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.Availability;

public interface IAvailabilityRepository
{
    Task<AvailabilityCalendarDto?> GetCalendarAsync(
        Guid hotelId,
        AvailabilityCalendarRequest request,
        DateTime utcNow,
        CancellationToken cancellationToken);

    Task<AvailabilityPersistenceResult> ApplyChangeAsync(
        Guid hotelId,
        ChangeAvailabilityRequest request,
        Guid actorUserAccountId,
        UserRoleCode actorHotelRole,
        DateTime utcNow,
        CancellationToken cancellationToken);
}
