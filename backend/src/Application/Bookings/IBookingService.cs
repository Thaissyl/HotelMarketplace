using HotelMarketplace.Application.Bookings.Dtos;
using HotelMarketplace.Application.Bookings.Requests;
using HotelMarketplace.SharedKernel.Results;

namespace HotelMarketplace.Application.Bookings;

public interface IBookingService
{
    Task<Result<IReadOnlyCollection<BookingDto>>> GetMyBookingsAsync(
        CancellationToken cancellationToken);

    Task<Result<BookingDto>> CreateBookingAsync(
        CreateBookingRequest request,
        CancellationToken cancellationToken);

    Task<Result<BookingCancellationQuoteDto>> GetCancellationQuoteAsync(
        Guid bookingId,
        CancellationToken cancellationToken);

    Task<Result<BookingCancellationResultDto>> CancelBookingAsync(
        Guid bookingId,
        CancelBookingRequest request,
        CancellationToken cancellationToken);
}
