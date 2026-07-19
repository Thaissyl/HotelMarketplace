using FluentValidation;
using FluentValidation.Results;
using HotelMarketplace.Application.Availability.Dtos;
using HotelMarketplace.Application.Availability.Requests;
using HotelMarketplace.Application.Common.Validation;
using HotelMarketplace.Application.Security;
using HotelMarketplace.Domain.Enums;
using HotelMarketplace.SharedKernel.Results;
using HotelMarketplace.SharedKernel.Time;

namespace HotelMarketplace.Application.Availability;

internal sealed class AvailabilityService : IAvailabilityService
{
    private static readonly UserRoleCode[] AllowedRoles =
    {
        UserRoleCode.PropertyOwner,
        UserRoleCode.HotelManager,
        UserRoleCode.Receptionist
    };

    private readonly IAvailabilityRepository _repository;
    private readonly ICurrentUserService _currentUserService;
    private readonly IHotelAccessAuthorizer _hotelAccessAuthorizer;
    private readonly IDateTimeProvider _dateTimeProvider;
    private readonly IValidator<AvailabilityCalendarRequest> _calendarValidator;
    private readonly IValidator<ChangeAvailabilityRequest> _changeValidator;

    public AvailabilityService(
        IAvailabilityRepository repository,
        ICurrentUserService currentUserService,
        IHotelAccessAuthorizer hotelAccessAuthorizer,
        IDateTimeProvider dateTimeProvider,
        IValidator<AvailabilityCalendarRequest> calendarValidator,
        IValidator<ChangeAvailabilityRequest> changeValidator)
    {
        _repository = repository;
        _currentUserService = currentUserService;
        _hotelAccessAuthorizer = hotelAccessAuthorizer;
        _dateTimeProvider = dateTimeProvider;
        _calendarValidator = calendarValidator;
        _changeValidator = changeValidator;
    }

    public async Task<Result<AvailabilityCalendarDto>> GetCalendarAsync(
        Guid hotelId,
        AvailabilityCalendarRequest request,
        CancellationToken cancellationToken)
    {
        UserRoleCode? hotelRole = await ResolveHotelRoleAsync(hotelId, cancellationToken);
        if (hotelRole is null)
        {
            return Result.Failure<AvailabilityCalendarDto>(AvailabilityErrors.Forbidden);
        }

        ValidationResult validation = await _calendarValidator.ValidateAsync(request, cancellationToken);
        if (!validation.IsValid)
        {
            return Result.Failure<AvailabilityCalendarDto>(
                ValidationErrorFormatter.ToResultError("Availability.InvalidRequest", validation));
        }

        AvailabilityCalendarDto? calendar = await _repository.GetCalendarAsync(
            hotelId,
            request,
            _dateTimeProvider.UtcNow,
            cancellationToken);

        return calendar is null
            ? Result.Failure<AvailabilityCalendarDto>(AvailabilityErrors.HotelNotFound)
            : Result.Success(calendar);
    }

    public async Task<Result<AvailabilityCalendarDto>> ApplyChangeAsync(
        Guid hotelId,
        ChangeAvailabilityRequest request,
        CancellationToken cancellationToken)
    {
        UserRoleCode? hotelRole = await ResolveHotelRoleAsync(hotelId, cancellationToken);
        if (hotelRole is null || _currentUserService.UserId is null)
        {
            return Result.Failure<AvailabilityCalendarDto>(AvailabilityErrors.Forbidden);
        }

        if (hotelRole == UserRoleCode.Receptionist &&
            (request.PhysicalRoomId is null ||
             request.Action is AvailabilityChangeAction.Open or AvailabilityChangeAction.Close))
        {
            return Result.Failure<AvailabilityCalendarDto>(AvailabilityErrors.Forbidden);
        }

        ValidationResult validation = await _changeValidator.ValidateAsync(request, cancellationToken);
        if (!validation.IsValid)
        {
            return Result.Failure<AvailabilityCalendarDto>(
                ValidationErrorFormatter.ToResultError("Availability.InvalidRequest", validation));
        }

        AvailabilityPersistenceResult result = await _repository.ApplyChangeAsync(
            hotelId,
            request,
            _currentUserService.UserId.Value,
            hotelRole.Value,
            _dateTimeProvider.UtcNow,
            cancellationToken);

        return result.Status switch
        {
            AvailabilityPersistenceStatus.Success => Result.Success(result.Calendar!),
            AvailabilityPersistenceStatus.HotelNotFound => Result.Failure<AvailabilityCalendarDto>(AvailabilityErrors.HotelNotFound),
            AvailabilityPersistenceStatus.RoomTypeNotFound => Result.Failure<AvailabilityCalendarDto>(AvailabilityErrors.RoomTypeNotFound),
            AvailabilityPersistenceStatus.PhysicalRoomNotFound => Result.Failure<AvailabilityCalendarDto>(AvailabilityErrors.PhysicalRoomNotFound),
            AvailabilityPersistenceStatus.ActiveBookingConflict => Result.Failure<AvailabilityCalendarDto>(AvailabilityErrors.ActiveBookingConflict),
            AvailabilityPersistenceStatus.LockUnavailable => Result.Failure<AvailabilityCalendarDto>(AvailabilityErrors.LockUnavailable),
            _ => Result.Failure<AvailabilityCalendarDto>(AvailabilityErrors.InvalidRequest)
        };
    }

    private async Task<UserRoleCode?> ResolveHotelRoleAsync(Guid hotelId, CancellationToken cancellationToken)
    {
        if (!await _hotelAccessAuthorizer.HasAccessAsync(hotelId, AllowedRoles, cancellationToken))
        {
            return null;
        }

        IReadOnlyCollection<HotelRoleAccess> accesses = await _hotelAccessAuthorizer
            .GetActiveAccessesAsync(cancellationToken);

        UserRoleCode[] precedence =
        {
            UserRoleCode.PropertyOwner,
            UserRoleCode.HotelManager,
            UserRoleCode.Receptionist
        };

        foreach (UserRoleCode role in precedence)
        {
            if (accesses.Any(access => access.HotelId == hotelId && access.Role == role))
            {
                return role;
            }
        }

        return null;
    }
}
