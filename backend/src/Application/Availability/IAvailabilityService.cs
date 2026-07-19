using HotelMarketplace.Application.Availability.Dtos;
using HotelMarketplace.Application.Availability.Requests;
using HotelMarketplace.SharedKernel.Results;

namespace HotelMarketplace.Application.Availability;

public interface IAvailabilityService
{
    Task<Result<AvailabilityCalendarDto>> GetCalendarAsync(
        Guid hotelId,
        AvailabilityCalendarRequest request,
        CancellationToken cancellationToken);

    Task<Result<AvailabilityCalendarDto>> ApplyChangeAsync(
        Guid hotelId,
        ChangeAvailabilityRequest request,
        CancellationToken cancellationToken);
}
