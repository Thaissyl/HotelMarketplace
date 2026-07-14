using HotelMarketplace.Application.Bookings.Dtos;
using HotelMarketplace.Application.Bookings.Requests;
using HotelMarketplace.SharedKernel.Results;

namespace HotelMarketplace.Application.Bookings;

public interface IBookingService
{
    Task<Result<BookingDto>> CreateBookingAsync(
        CreateBookingRequest request,
        CancellationToken cancellationToken);
}
