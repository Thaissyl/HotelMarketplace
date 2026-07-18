using FluentValidation;
using FluentValidation.Results;
using HotelMarketplace.Application.Common.Validation;
using HotelMarketplace.Application.FrontDesk.Dtos;
using HotelMarketplace.Application.FrontDesk.Requests;
using HotelMarketplace.Application.HotelManagement.Dtos;
using HotelMarketplace.Application.Security;
using HotelMarketplace.Domain.Entities;
using HotelMarketplace.Domain.Enums;
using HotelMarketplace.SharedKernel.Results;

namespace HotelMarketplace.Application.FrontDesk;

internal sealed class FrontDeskService : IFrontDeskService
{
    private static readonly UserRoleCode[] AllowedRoles =
    {
        UserRoleCode.Receptionist,
        UserRoleCode.HotelManager,
        UserRoleCode.PropertyOwner,
        UserRoleCode.PlatformAdministrator
    };

    private readonly ICurrentUserService _currentUserService;
    private readonly IFrontDeskRepository _frontDeskRepository;
    private readonly IValidator<CheckInBookingRequest> _checkInValidator;
    private readonly IValidator<CheckOutBookingRequest> _checkOutValidator;
    private readonly IValidator<CreateWalkInBookingRequest> _walkInValidator;

    public FrontDeskService(
        ICurrentUserService currentUserService,
        IFrontDeskRepository frontDeskRepository,
        IValidator<CheckInBookingRequest> checkInValidator,
        IValidator<CheckOutBookingRequest> checkOutValidator,
        IValidator<CreateWalkInBookingRequest> walkInValidator)
    {
        _currentUserService = currentUserService;
        _frontDeskRepository = frontDeskRepository;
        _checkInValidator = checkInValidator;
        _checkOutValidator = checkOutValidator;
        _walkInValidator = walkInValidator;
    }

    public async Task<Result<IReadOnlyCollection<PhysicalRoomDto>>> GetPhysicalRoomsAsync(
        Guid hotelId,
        Guid? roomTypeId,
        CancellationToken cancellationToken)
    {
        Result? authorizationFailure = ValidateAuthorization(hotelId);
        if (authorizationFailure is not null)
        {
            return Result.Failure<IReadOnlyCollection<PhysicalRoomDto>>(authorizationFailure.Error);
        }

        IReadOnlyCollection<PhysicalRoom> rooms = await _frontDeskRepository.GetPhysicalRoomsAsync(
            hotelId,
            roomTypeId,
            cancellationToken);

        return rooms.Select(room => new PhysicalRoomDto(
            room.Id,
            room.HotelId,
            room.RoomTypeId,
            room.RoomNumber,
            room.Status)).ToArray();
    }

    public async Task<Result<IReadOnlyCollection<FrontDeskBookingSummaryDto>>> GetBookingsAsync(
        Guid hotelId,
        BookingStatus? status,
        DateOnly? fromDate,
        DateOnly? toDate,
        CancellationToken cancellationToken)
    {
        Result? authorizationFailure = ValidateAuthorization(hotelId);
        if (authorizationFailure is not null)
        {
            return Result.Failure<IReadOnlyCollection<FrontDeskBookingSummaryDto>>(authorizationFailure.Error);
        }

        IReadOnlyCollection<FrontDeskBookingSummaryDto> bookings = await _frontDeskRepository.GetBookingsAsync(
            hotelId,
            status,
            fromDate,
            toDate,
            cancellationToken);

        return Result.Success(bookings);
    }

    public async Task<Result<FrontDeskBookingDto>> CheckInBookingAsync(
        Guid hotelId,
        Guid bookingId,
        CheckInBookingRequest request,
        CancellationToken cancellationToken)
    {
        Result? authorizationFailure = ValidateAuthorization(hotelId);
        if (authorizationFailure is not null)
        {
            return Result.Failure<FrontDeskBookingDto>(authorizationFailure.Error);
        }

        ValidationResult validationResult = await _checkInValidator.ValidateAsync(request, cancellationToken);
        if (!validationResult.IsValid)
        {
            return Result.Failure<FrontDeskBookingDto>(
                ValidationErrorFormatter.ToResultError("FrontDesk.InvalidCheckInRequest", validationResult));
        }

        FrontDeskPersistenceResult result = await _frontDeskRepository.CheckInBookingAsync(
            hotelId,
            bookingId,
            _currentUserService.UserId!.Value,
            request,
            cancellationToken);

        return ToResult(result);
    }

    public async Task<Result<FrontDeskBookingDto>> CheckOutBookingAsync(
        Guid hotelId,
        Guid bookingId,
        CheckOutBookingRequest request,
        CancellationToken cancellationToken)
    {
        Result? authorizationFailure = ValidateAuthorization(hotelId);
        if (authorizationFailure is not null)
        {
            return Result.Failure<FrontDeskBookingDto>(authorizationFailure.Error);
        }

        ValidationResult validationResult = await _checkOutValidator.ValidateAsync(request, cancellationToken);
        if (!validationResult.IsValid)
        {
            return Result.Failure<FrontDeskBookingDto>(
                ValidationErrorFormatter.ToResultError("FrontDesk.InvalidCheckOutRequest", validationResult));
        }

        FrontDeskPersistenceResult result = await _frontDeskRepository.CheckOutBookingAsync(
            hotelId,
            bookingId,
            _currentUserService.UserId!.Value,
            request,
            cancellationToken);

        return ToResult(result);
    }

    public async Task<Result<FrontDeskBookingDto>> CreateWalkInBookingAsync(
        Guid hotelId,
        CreateWalkInBookingRequest request,
        CancellationToken cancellationToken)
    {
        Result? authorizationFailure = ValidateAuthorization(hotelId);
        if (authorizationFailure is not null)
        {
            return Result.Failure<FrontDeskBookingDto>(authorizationFailure.Error);
        }

        ValidationResult validationResult = await _walkInValidator.ValidateAsync(request, cancellationToken);
        if (!validationResult.IsValid)
        {
            return Result.Failure<FrontDeskBookingDto>(
                ValidationErrorFormatter.ToResultError("FrontDesk.InvalidWalkInBookingRequest", validationResult));
        }

        FrontDeskPersistenceResult result = await _frontDeskRepository.CreateWalkInBookingAsync(
            hotelId,
            _currentUserService.UserId!.Value,
            request,
            cancellationToken);

        return ToResult(result);
    }

    private Result? ValidateAuthorization(Guid hotelId)
    {
        if (_currentUserService.UserId is null ||
            !_currentUserService.Roles.Any(role => AllowedRoles.Contains(role)))
        {
            return Result.Failure(FrontDeskErrors.Forbidden);
        }

        if (_currentUserService.Roles.Contains(UserRoleCode.PlatformAdministrator))
        {
            return null;
        }

        return _currentUserService.HotelIds.Contains(hotelId)
            ? null
            : Result.Failure(FrontDeskErrors.Forbidden);
    }

    private static Result<FrontDeskBookingDto> ToResult(FrontDeskPersistenceResult result)
    {
        return result.Status switch
        {
            FrontDeskPersistenceStatus.Success => Result.Success(result.Booking!),
            FrontDeskPersistenceStatus.BookingNotFound => Result.Failure<FrontDeskBookingDto>(FrontDeskErrors.BookingNotFound),
            FrontDeskPersistenceStatus.RoomTypeNotAvailable => Result.Failure<FrontDeskBookingDto>(FrontDeskErrors.RoomTypeNotAvailable),
            FrontDeskPersistenceStatus.InvalidBookingStatusForCheckIn => Result.Failure<FrontDeskBookingDto>(FrontDeskErrors.InvalidBookingStatusForCheckIn),
            FrontDeskPersistenceStatus.InvalidBookingStatusForCheckOut => Result.Failure<FrontDeskBookingDto>(FrontDeskErrors.InvalidBookingStatusForCheckOut),
            FrontDeskPersistenceStatus.InvalidRoomAssignment => Result.Failure<FrontDeskBookingDto>(FrontDeskErrors.InvalidRoomAssignment),
            FrontDeskPersistenceStatus.RoomAssignmentOverlap => Result.Failure<FrontDeskBookingDto>(FrontDeskErrors.RoomAssignmentOverlap),
            FrontDeskPersistenceStatus.PaymentCollectionRequired => Result.Failure<FrontDeskBookingDto>(FrontDeskErrors.PaymentCollectionRequired),
            FrontDeskPersistenceStatus.CapacityExceeded => Result.Failure<FrontDeskBookingDto>(FrontDeskErrors.CapacityExceeded),
            FrontDeskPersistenceStatus.LockUnavailable => Result.Failure<FrontDeskBookingDto>(FrontDeskErrors.LockUnavailable),
            _ => Result.Failure<FrontDeskBookingDto>(FrontDeskErrors.InvalidRoomAssignment)
        };
    }
}
