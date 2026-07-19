using FluentValidation;
using FluentValidation.Results;
using HotelMarketplace.Application.Bookings.Dtos;
using HotelMarketplace.Application.Bookings.Requests;
using HotelMarketplace.Application.Common.Validation;
using HotelMarketplace.Application.Security;
using HotelMarketplace.Domain.Enums;
using HotelMarketplace.SharedKernel.Results;

namespace HotelMarketplace.Application.Bookings;

internal sealed class BookingService : IBookingService
{
    private readonly IBookingRepository _bookingRepository;
    private readonly ICurrentUserService _currentUserService;
    private readonly IValidator<CreateBookingRequest> _createBookingValidator;

    public BookingService(
        IBookingRepository bookingRepository,
        ICurrentUserService currentUserService,
        IValidator<CreateBookingRequest> createBookingValidator)
    {
        _bookingRepository = bookingRepository;
        _currentUserService = currentUserService;
        _createBookingValidator = createBookingValidator;
    }

    public async Task<Result<BookingDto>> CreateBookingAsync(
        CreateBookingRequest request,
        CancellationToken cancellationToken)
    {
        if (_currentUserService.UserId is null ||
            !_currentUserService.Roles.Contains(UserRoleCode.Customer))
        {
            return Result.Failure<BookingDto>(BookingErrors.Forbidden);
        }

        ValidationResult validationResult = await _createBookingValidator.ValidateAsync(request, cancellationToken);
        if (!validationResult.IsValid)
        {
            return Result.Failure<BookingDto>(
                ValidationErrorFormatter.ToResultError("Booking.InvalidBookingRequest", validationResult));
        }

        CreateBookingRepositoryRequest repositoryRequest = new(
            _currentUserService.UserId.Value,
            request.HotelId,
            request.RoomTypeId,
            request.CheckInDate,
            request.CheckOutDate,
            request.RoomCount,
            request.GuestCount,
            request.GuestFullName,
            request.GuestPhone);

        CreateBookingRepositoryResult reservationResult = await _bookingRepository.CreatePendingBookingAsync(repositoryRequest, cancellationToken);

        return reservationResult.Status switch
        {
            CreateBookingRepositoryStatus.Success => Result.Success(reservationResult.Booking!),
            CreateBookingRepositoryStatus.HotelNotAvailable => Result.Failure<BookingDto>(BookingErrors.HotelNotAvailable),
            CreateBookingRepositoryStatus.RoomTypeNotAvailable => Result.Failure<BookingDto>(BookingErrors.RoomTypeNotAvailable),
            CreateBookingRepositoryStatus.CapacityExceeded => Result.Failure<BookingDto>(BookingErrors.CapacityExceeded),
            CreateBookingRepositoryStatus.InsufficientAvailability => Result.Failure<BookingDto>(BookingErrors.InsufficientAvailability),
            CreateBookingRepositoryStatus.ReservationLockUnavailable => Result.Failure<BookingDto>(BookingErrors.ReservationLockUnavailable),
            _ => Result.Failure<BookingDto>(BookingErrors.InsufficientAvailability)
        };
    }

    public async Task<Result<IReadOnlyCollection<BookingDto>>> GetMyBookingsAsync(CancellationToken cancellationToken)
    {
        if (_currentUserService.UserId is null ||
            !_currentUserService.Roles.Contains(UserRoleCode.Customer))
        {
            return Result.Failure<IReadOnlyCollection<BookingDto>>(BookingErrors.Forbidden);
        }

        IReadOnlyCollection<BookingDto> bookings = await _bookingRepository.GetBookingsForCustomerAsync(
            _currentUserService.UserId.Value,
            cancellationToken);

        return Result.Success(bookings);
    }
}
