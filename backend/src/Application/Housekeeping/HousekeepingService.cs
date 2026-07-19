using FluentValidation;
using FluentValidation.Results;
using HotelMarketplace.Application.Common.Validation;
using HotelMarketplace.Application.Housekeeping.Dtos;
using HotelMarketplace.Application.Housekeeping.Requests;
using HotelMarketplace.Application.Security;
using HotelMarketplace.Domain.Enums;
using HotelMarketplace.SharedKernel.Results;

namespace HotelMarketplace.Application.Housekeeping;

internal sealed class HousekeepingService : IHousekeepingService
{
    private static readonly UserRoleCode[] AllowedRoles =
    {
        UserRoleCode.HousekeepingStaff,
        UserRoleCode.HotelManager,
        UserRoleCode.PropertyOwner
    };

    private readonly ICurrentUserService _currentUserService;
    private readonly IHotelAccessAuthorizer _hotelAccessAuthorizer;
    private readonly IHousekeepingRepository _housekeepingRepository;
    private readonly IValidator<HousekeepingTaskQueryRequest> _queryValidator;
    private readonly IValidator<UpdateHousekeepingTaskStatusRequest> _updateValidator;
    private readonly IValidator<AssignHousekeepingTaskRequest> _assignValidator;

    public HousekeepingService(
        ICurrentUserService currentUserService,
        IHotelAccessAuthorizer hotelAccessAuthorizer,
        IHousekeepingRepository housekeepingRepository,
        IValidator<HousekeepingTaskQueryRequest> queryValidator,
        IValidator<UpdateHousekeepingTaskStatusRequest> updateValidator,
        IValidator<AssignHousekeepingTaskRequest> assignValidator)
    {
        _currentUserService = currentUserService;
        _hotelAccessAuthorizer = hotelAccessAuthorizer;
        _housekeepingRepository = housekeepingRepository;
        _queryValidator = queryValidator;
        _updateValidator = updateValidator;
        _assignValidator = assignValidator;
    }

    public async Task<Result<IReadOnlyCollection<HousekeepingTaskDto>>> GetTasksAsync(
        Guid hotelId,
        HousekeepingTaskQueryRequest request,
        CancellationToken cancellationToken)
    {
        Result? authorizationFailure = await ValidateAuthorizationAsync(hotelId, AllowedRoles, cancellationToken);
        if (authorizationFailure is not null)
        {
            return Result.Failure<IReadOnlyCollection<HousekeepingTaskDto>>(authorizationFailure.Error);
        }

        ValidationResult validationResult = await _queryValidator.ValidateAsync(request, cancellationToken);
        if (!validationResult.IsValid)
        {
            return Result.Failure<IReadOnlyCollection<HousekeepingTaskDto>>(
                ValidationErrorFormatter.ToResultError("Housekeeping.InvalidTaskQuery", validationResult));
        }

        IReadOnlyCollection<HousekeepingTaskDto> tasks = await _housekeepingRepository.GetTasksAsync(
            hotelId,
            request,
            cancellationToken);

        return Result.Success(tasks);
    }

    public async Task<Result<HousekeepingTaskDto>> UpdateTaskStatusAsync(
        Guid hotelId,
        Guid taskId,
        UpdateHousekeepingTaskStatusRequest request,
        CancellationToken cancellationToken)
    {
        Result? authorizationFailure = await ValidateAuthorizationAsync(hotelId, AllowedRoles, cancellationToken);
        if (authorizationFailure is not null)
        {
            return Result.Failure<HousekeepingTaskDto>(authorizationFailure.Error);
        }

        ValidationResult validationResult = await _updateValidator.ValidateAsync(request, cancellationToken);
        if (!validationResult.IsValid)
        {
            return Result.Failure<HousekeepingTaskDto>(
                ValidationErrorFormatter.ToResultError("Housekeeping.InvalidTaskStatusUpdate", validationResult));
        }

        HousekeepingTaskUpdateResult result = await _housekeepingRepository.UpdateTaskStatusAsync(
            hotelId,
            taskId,
            _currentUserService.UserId!.Value,
            request.Status,
            cancellationToken);

        return result.Status switch
        {
            HousekeepingPersistenceStatus.Success => Result.Success(result.Task!),
            HousekeepingPersistenceStatus.TaskNotFound => Result.Failure<HousekeepingTaskDto>(HousekeepingErrors.TaskNotFound),
            HousekeepingPersistenceStatus.RoomNotFound => Result.Failure<HousekeepingTaskDto>(HousekeepingErrors.RoomNotFound),
            HousekeepingPersistenceStatus.InvalidTransition => Result.Failure<HousekeepingTaskDto>(HousekeepingErrors.InvalidTransition),
            HousekeepingPersistenceStatus.LockUnavailable => Result.Failure<HousekeepingTaskDto>(HousekeepingErrors.LockUnavailable),
            HousekeepingPersistenceStatus.AssigneeNotFound => Result.Failure<HousekeepingTaskDto>(HousekeepingErrors.AssigneeNotFound),
            _ => Result.Failure<HousekeepingTaskDto>(HousekeepingErrors.InvalidTransition)
        };
    }

    public async Task<Result<HousekeepingTaskDto>> AssignTaskAsync(
        Guid hotelId,
        Guid taskId,
        AssignHousekeepingTaskRequest request,
        CancellationToken cancellationToken)
    {
        UserRoleCode[] assignmentRoles = { UserRoleCode.HotelManager, UserRoleCode.PropertyOwner };
        Result? authorizationFailure = await ValidateAuthorizationAsync(hotelId, assignmentRoles, cancellationToken);
        if (authorizationFailure is not null)
        {
            return Result.Failure<HousekeepingTaskDto>(authorizationFailure.Error);
        }

        ValidationResult validationResult = await _assignValidator.ValidateAsync(request, cancellationToken);
        if (!validationResult.IsValid)
        {
            return Result.Failure<HousekeepingTaskDto>(
                ValidationErrorFormatter.ToResultError("Housekeeping.InvalidTaskAssignment", validationResult));
        }

        HousekeepingTaskUpdateResult result = await _housekeepingRepository.AssignTaskAsync(
            hotelId,
            taskId,
            request.AssignedToUserAccountId,
            cancellationToken);

        return result.Status switch
        {
            HousekeepingPersistenceStatus.Success => Result.Success(result.Task!),
            HousekeepingPersistenceStatus.TaskNotFound => Result.Failure<HousekeepingTaskDto>(HousekeepingErrors.TaskNotFound),
            HousekeepingPersistenceStatus.AssigneeNotFound => Result.Failure<HousekeepingTaskDto>(HousekeepingErrors.AssigneeNotFound),
            HousekeepingPersistenceStatus.InvalidTransition => Result.Failure<HousekeepingTaskDto>(HousekeepingErrors.InvalidTransition),
            HousekeepingPersistenceStatus.LockUnavailable => Result.Failure<HousekeepingTaskDto>(HousekeepingErrors.LockUnavailable),
            _ => Result.Failure<HousekeepingTaskDto>(HousekeepingErrors.InvalidTransition)
        };
    }

    private async Task<Result?> ValidateAuthorizationAsync(
        Guid hotelId,
        IReadOnlyCollection<UserRoleCode> allowedRoles,
        CancellationToken cancellationToken)
    {
        if (_currentUserService.UserId is null)
        {
            return Result.Failure(HousekeepingErrors.Forbidden);
        }

        return await _hotelAccessAuthorizer.HasAccessAsync(hotelId, allowedRoles, cancellationToken)
            ? null
            : Result.Failure(HousekeepingErrors.Forbidden);
    }
}
