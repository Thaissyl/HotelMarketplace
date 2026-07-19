using FluentValidation;
using FluentValidation.Results;
using HotelMarketplace.Application.Common.Validation;
using HotelMarketplace.Application.HotelManagement.Dtos;
using HotelMarketplace.Application.Maintenance.Dtos;
using HotelMarketplace.Application.Maintenance.Requests;
using HotelMarketplace.Application.Security;
using HotelMarketplace.Domain.Enums;
using HotelMarketplace.SharedKernel.Results;

namespace HotelMarketplace.Application.Maintenance;

internal sealed class MaintenanceService : IMaintenanceService
{
    private static readonly UserRoleCode[] ViewAndUpdateRoles =
    {
        UserRoleCode.MaintenanceStaff,
        UserRoleCode.HotelManager,
        UserRoleCode.PropertyOwner
    };

    private static readonly UserRoleCode[] ReportIssueRoles =
    {
        UserRoleCode.HousekeepingStaff,
        UserRoleCode.MaintenanceStaff,
        UserRoleCode.HotelManager,
        UserRoleCode.PropertyOwner
    };

    private readonly ICurrentUserService _currentUserService;
    private readonly IHotelAccessAuthorizer _hotelAccessAuthorizer;
    private readonly IMaintenanceRepository _maintenanceRepository;
    private readonly IValidator<MaintenanceRequestQueryRequest> _queryValidator;
    private readonly IValidator<ReportRoomIssueRequest> _reportValidator;
    private readonly IValidator<UpdateMaintenanceRequestStatusRequest> _updateValidator;
    private readonly IValidator<AssignMaintenanceRequestRequest> _assignValidator;

    public MaintenanceService(
        ICurrentUserService currentUserService,
        IHotelAccessAuthorizer hotelAccessAuthorizer,
        IMaintenanceRepository maintenanceRepository,
        IValidator<MaintenanceRequestQueryRequest> queryValidator,
        IValidator<ReportRoomIssueRequest> reportValidator,
        IValidator<UpdateMaintenanceRequestStatusRequest> updateValidator,
        IValidator<AssignMaintenanceRequestRequest> assignValidator)
    {
        _currentUserService = currentUserService;
        _hotelAccessAuthorizer = hotelAccessAuthorizer;
        _maintenanceRepository = maintenanceRepository;
        _queryValidator = queryValidator;
        _reportValidator = reportValidator;
        _updateValidator = updateValidator;
        _assignValidator = assignValidator;
    }

    public async Task<Result<IReadOnlyCollection<MaintenanceRequestDto>>> GetRequestsAsync(
        Guid hotelId,
        MaintenanceRequestQueryRequest request,
        CancellationToken cancellationToken)
    {
        Result? authorizationFailure = await ValidateAuthorizationAsync(hotelId, ViewAndUpdateRoles, cancellationToken);
        if (authorizationFailure is not null)
        {
            return Result.Failure<IReadOnlyCollection<MaintenanceRequestDto>>(authorizationFailure.Error);
        }

        ValidationResult validationResult = await _queryValidator.ValidateAsync(request, cancellationToken);
        if (!validationResult.IsValid)
        {
            return Result.Failure<IReadOnlyCollection<MaintenanceRequestDto>>(
                ValidationErrorFormatter.ToResultError("Maintenance.InvalidRequestQuery", validationResult));
        }

        IReadOnlyCollection<MaintenanceRequestDto> requests = await _maintenanceRepository.GetRequestsAsync(
            hotelId,
            request,
            cancellationToken);

        return Result.Success(requests);
    }

    public async Task<Result<IReadOnlyCollection<PhysicalRoomDto>>> GetRoomsAsync(
        Guid hotelId,
        CancellationToken cancellationToken)
    {
        Result? authorizationFailure = await ValidateAuthorizationAsync(hotelId, ReportIssueRoles, cancellationToken);
        if (authorizationFailure is not null)
        {
            return Result.Failure<IReadOnlyCollection<PhysicalRoomDto>>(authorizationFailure.Error);
        }

        IReadOnlyCollection<PhysicalRoomDto> rooms = await _maintenanceRepository.GetRoomsAsync(
            hotelId,
            cancellationToken);

        return Result.Success(rooms);
    }

    public async Task<Result<MaintenanceRequestDto>> ReportRoomIssueAsync(
        Guid hotelId,
        ReportRoomIssueRequest request,
        CancellationToken cancellationToken)
    {
        Result? authorizationFailure = await ValidateAuthorizationAsync(hotelId, ReportIssueRoles, cancellationToken);
        if (authorizationFailure is not null)
        {
            return Result.Failure<MaintenanceRequestDto>(authorizationFailure.Error);
        }

        ValidationResult validationResult = await _reportValidator.ValidateAsync(request, cancellationToken);
        if (!validationResult.IsValid)
        {
            return Result.Failure<MaintenanceRequestDto>(
                ValidationErrorFormatter.ToResultError("Maintenance.InvalidRoomIssueReport", validationResult));
        }

        MaintenanceRequestPersistenceResult result = await _maintenanceRepository.ReportRoomIssueAsync(
            hotelId,
            _currentUserService.UserId!.Value,
            request,
            cancellationToken);

        return ToResult(result);
    }

    public async Task<Result<MaintenanceRequestDto>> AssignRequestAsync(
        Guid hotelId,
        Guid requestId,
        AssignMaintenanceRequestRequest request,
        CancellationToken cancellationToken)
    {
        UserRoleCode[] assignmentRoles = { UserRoleCode.HotelManager, UserRoleCode.PropertyOwner };
        Result? authorizationFailure = await ValidateAuthorizationAsync(hotelId, assignmentRoles, cancellationToken);
        if (authorizationFailure is not null)
        {
            return Result.Failure<MaintenanceRequestDto>(authorizationFailure.Error);
        }

        ValidationResult validationResult = await _assignValidator.ValidateAsync(request, cancellationToken);
        if (!validationResult.IsValid)
        {
            return Result.Failure<MaintenanceRequestDto>(
                ValidationErrorFormatter.ToResultError("Maintenance.InvalidRequestAssignment", validationResult));
        }

        MaintenanceRequestPersistenceResult result = await _maintenanceRepository.AssignRequestAsync(
            hotelId,
            requestId,
            request.AssignedToUserAccountId,
            cancellationToken);

        return ToResult(result);
    }

    public async Task<Result<MaintenanceRequestDto>> UpdateRequestStatusAsync(
        Guid hotelId,
        Guid requestId,
        UpdateMaintenanceRequestStatusRequest request,
        CancellationToken cancellationToken)
    {
        Result? authorizationFailure = await ValidateAuthorizationAsync(hotelId, ViewAndUpdateRoles, cancellationToken);
        if (authorizationFailure is not null)
        {
            return Result.Failure<MaintenanceRequestDto>(authorizationFailure.Error);
        }

        ValidationResult validationResult = await _updateValidator.ValidateAsync(request, cancellationToken);
        if (!validationResult.IsValid)
        {
            return Result.Failure<MaintenanceRequestDto>(
                ValidationErrorFormatter.ToResultError("Maintenance.InvalidStatusUpdate", validationResult));
        }

        MaintenanceRequestPersistenceResult result = await _maintenanceRepository.UpdateRequestStatusAsync(
            hotelId,
            requestId,
            _currentUserService.UserId!.Value,
            request.Status,
            cancellationToken);

        return ToResult(result);
    }

    private async Task<Result?> ValidateAuthorizationAsync(
        Guid hotelId,
        IReadOnlyCollection<UserRoleCode> allowedRoles,
        CancellationToken cancellationToken)
    {
        if (_currentUserService.UserId is null)
        {
            return Result.Failure(MaintenanceErrors.Forbidden);
        }

        return await _hotelAccessAuthorizer.HasAccessAsync(hotelId, allowedRoles, cancellationToken)
            ? null
            : Result.Failure(MaintenanceErrors.Forbidden);
    }

    private static Result<MaintenanceRequestDto> ToResult(MaintenanceRequestPersistenceResult result)
    {
        return result.Status switch
        {
            MaintenancePersistenceStatus.Success => Result.Success(result.Request!),
            MaintenancePersistenceStatus.RequestNotFound => Result.Failure<MaintenanceRequestDto>(MaintenanceErrors.RequestNotFound),
            MaintenancePersistenceStatus.RoomNotFound => Result.Failure<MaintenanceRequestDto>(MaintenanceErrors.RoomNotFound),
            MaintenancePersistenceStatus.InvalidTransition => Result.Failure<MaintenanceRequestDto>(MaintenanceErrors.InvalidTransition),
            MaintenancePersistenceStatus.InvalidRoomStatus => Result.Failure<MaintenanceRequestDto>(MaintenanceErrors.InvalidRoomStatus),
            MaintenancePersistenceStatus.LockUnavailable => Result.Failure<MaintenanceRequestDto>(MaintenanceErrors.LockUnavailable),
            MaintenancePersistenceStatus.AssigneeNotFound => Result.Failure<MaintenanceRequestDto>(MaintenanceErrors.AssigneeNotFound),
            _ => Result.Failure<MaintenanceRequestDto>(MaintenanceErrors.InvalidTransition)
        };
    }
}
