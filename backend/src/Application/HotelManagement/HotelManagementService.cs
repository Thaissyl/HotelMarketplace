using FluentValidation;
using FluentValidation.Results;
using HotelMarketplace.Application.Authentication;
using HotelMarketplace.Application.Common.Validation;
using HotelMarketplace.Application.HotelManagement.Dtos;
using HotelMarketplace.Application.HotelManagement.Requests;
using HotelMarketplace.Application.Security;
using HotelMarketplace.Domain.Entities;
using HotelMarketplace.Domain.Enums;
using HotelMarketplace.SharedKernel.Results;
using HotelMarketplace.SharedKernel.Time;

namespace HotelMarketplace.Application.HotelManagement;

internal sealed class HotelManagementService : IHotelManagementService
{
    private readonly IHotelManagementRepository _repository;
    private readonly ICurrentUserService _currentUserService;
    private readonly IHotelAccessAuthorizer _hotelAccessAuthorizer;
    private readonly IDateTimeProvider _dateTimeProvider;
    private readonly IPasswordHasher _passwordHasher;
    private readonly IValidator<RegisterHotelRequest> _registerHotelValidator;
    private readonly IValidator<UpdateHotelProfileRequest> _updateHotelProfileValidator;
    private readonly IValidator<UpdateHotelContentRequest> _updateHotelContentValidator;
    private readonly IValidator<CreateHotelStaffRequest> _createHotelStaffValidator;
    private readonly IValidator<AttachHotelStaffRequest> _attachHotelStaffValidator;
    private readonly IValidator<UpdateHotelStaffAssignmentRequest> _updateHotelStaffAssignmentValidator;
    private readonly IValidator<CreateRoomTypeRequest> _createRoomTypeValidator;
    private readonly IValidator<UpdateRoomTypeRequest> _updateRoomTypeValidator;
    private readonly IValidator<CreatePhysicalRoomRequest> _createPhysicalRoomValidator;
    private readonly IValidator<UpdatePhysicalRoomRequest> _updatePhysicalRoomValidator;

    public HotelManagementService(
        IHotelManagementRepository repository,
        ICurrentUserService currentUserService,
        IHotelAccessAuthorizer hotelAccessAuthorizer,
        IDateTimeProvider dateTimeProvider,
        IPasswordHasher passwordHasher,
        IValidator<RegisterHotelRequest> registerHotelValidator,
        IValidator<UpdateHotelProfileRequest> updateHotelProfileValidator,
        IValidator<UpdateHotelContentRequest> updateHotelContentValidator,
        IValidator<CreateHotelStaffRequest> createHotelStaffValidator,
        IValidator<AttachHotelStaffRequest> attachHotelStaffValidator,
        IValidator<UpdateHotelStaffAssignmentRequest> updateHotelStaffAssignmentValidator,
        IValidator<CreateRoomTypeRequest> createRoomTypeValidator,
        IValidator<UpdateRoomTypeRequest> updateRoomTypeValidator,
        IValidator<CreatePhysicalRoomRequest> createPhysicalRoomValidator,
        IValidator<UpdatePhysicalRoomRequest> updatePhysicalRoomValidator)
    {
        _repository = repository;
        _currentUserService = currentUserService;
        _hotelAccessAuthorizer = hotelAccessAuthorizer;
        _dateTimeProvider = dateTimeProvider;
        _passwordHasher = passwordHasher;
        _registerHotelValidator = registerHotelValidator;
        _updateHotelProfileValidator = updateHotelProfileValidator;
        _updateHotelContentValidator = updateHotelContentValidator;
        _createHotelStaffValidator = createHotelStaffValidator;
        _attachHotelStaffValidator = attachHotelStaffValidator;
        _updateHotelStaffAssignmentValidator = updateHotelStaffAssignmentValidator;
        _createRoomTypeValidator = createRoomTypeValidator;
        _updateRoomTypeValidator = updateRoomTypeValidator;
        _createPhysicalRoomValidator = createPhysicalRoomValidator;
        _updatePhysicalRoomValidator = updatePhysicalRoomValidator;
    }

    public async Task<Result<HotelDto>> RegisterHotelAsync(RegisterHotelRequest request, CancellationToken cancellationToken)
    {
        Result? accessFailure = EnsurePropertyOwner();
        if (accessFailure is not null)
        {
            return Result.Failure<HotelDto>(accessFailure.Error);
        }

        ValidationResult validationResult = await _registerHotelValidator.ValidateAsync(request, cancellationToken);
        if (!validationResult.IsValid)
        {
            return Result.Failure<HotelDto>(ValidationErrorFormatter.ToResultError("HotelManagement.InvalidHotelProfile", validationResult));
        }

        HotelProperty hotel = new(
            Guid.NewGuid(),
            _currentUserService.UserId!.Value,
            request.Name,
            request.City,
            request.AddressLine,
            request.ContactEmail,
            request.ContactPhone,
            request.Description);

        await _repository.AddHotelAsync(hotel, cancellationToken);

        return ToHotelDto(hotel);
    }

    public async Task<Result<IReadOnlyCollection<HotelDto>>> GetMyHotelsAsync(CancellationToken cancellationToken)
    {
        Result? accessFailure = EnsurePropertyOwner();
        if (accessFailure is not null)
        {
            return Result.Failure<IReadOnlyCollection<HotelDto>>(accessFailure.Error);
        }

        IReadOnlyCollection<HotelProperty> hotels = await _repository.GetHotelsOwnedByAsync(_currentUserService.UserId!.Value, cancellationToken);

        return hotels.Select(ToHotelDto).ToArray();
    }

    public async Task<Result<IReadOnlyCollection<HotelDto>>> GetAccessibleOperationHotelsAsync(CancellationToken cancellationToken)
    {
        if (_currentUserService.UserId is null)
        {
            return Result.Failure<IReadOnlyCollection<HotelDto>>(HotelManagementErrors.Forbidden);
        }

        UserRoleCode[] operationRoles =
        {
            UserRoleCode.PropertyOwner,
            UserRoleCode.HotelManager,
            UserRoleCode.Receptionist,
            UserRoleCode.HousekeepingStaff,
            UserRoleCode.MaintenanceStaff
        };
        IReadOnlyCollection<HotelRoleAccess> activeAccesses = await _hotelAccessAuthorizer
            .GetActiveAccessesAsync(cancellationToken);
        Guid[] accessibleHotelIds = activeAccesses
            .Where(access => operationRoles.Contains(access.Role))
            .Select(access => access.HotelId)
            .Distinct()
            .ToArray();

        if (accessibleHotelIds.Length == 0)
        {
            return Result.Failure<IReadOnlyCollection<HotelDto>>(HotelManagementErrors.Forbidden);
        }

        IReadOnlyCollection<HotelProperty> hotels = await _repository.GetHotelsByIdsAsync(
            accessibleHotelIds,
            cancellationToken);

        return Result.Success<IReadOnlyCollection<HotelDto>>(hotels.Select(ToHotelDto).ToArray());
    }

    public async Task<Result<HotelDto>> GetHotelAsync(Guid hotelId, CancellationToken cancellationToken)
    {
        Result? accessFailure = await EnsureOwnedHotelAsync(hotelId, cancellationToken);
        if (accessFailure is not null)
        {
            return Result.Failure<HotelDto>(accessFailure.Error);
        }

        HotelProperty? hotel = await _repository.GetHotelByIdAsync(hotelId, cancellationToken);

        return hotel is null
            ? Result.Failure<HotelDto>(HotelManagementErrors.HotelNotFound)
            : ToHotelDto(hotel);
    }

    public async Task<Result<HotelDto>> UpdateHotelProfileAsync(Guid hotelId, UpdateHotelProfileRequest request, CancellationToken cancellationToken)
    {
        Result? accessFailure = await EnsureOwnedHotelAsync(hotelId, cancellationToken);
        if (accessFailure is not null)
        {
            return Result.Failure<HotelDto>(accessFailure.Error);
        }

        ValidationResult validationResult = await _updateHotelProfileValidator.ValidateAsync(request, cancellationToken);
        if (!validationResult.IsValid)
        {
            return Result.Failure<HotelDto>(ValidationErrorFormatter.ToResultError("HotelManagement.InvalidHotelProfile", validationResult));
        }

        HotelProperty? hotel = await _repository.GetHotelByIdAsync(hotelId, cancellationToken);
        if (hotel is null)
        {
            return Result.Failure<HotelDto>(HotelManagementErrors.HotelNotFound);
        }

        hotel.UpdateProfile(request.Name, request.City, request.AddressLine, request.ContactEmail, request.ContactPhone, request.Description);
        if (request.RequiresRoomInspection.HasValue)
        {
            hotel.ConfigureRoomInspection(request.RequiresRoomInspection.Value);
        }
        await _repository.SaveChangesAsync(cancellationToken);

        return ToHotelDto(hotel);
    }

    public async Task<Result<HotelContentDto>> GetHotelContentAsync(Guid hotelId, CancellationToken cancellationToken)
    {
        Result? accessFailure = await EnsureOwnedHotelAsync(hotelId, cancellationToken);
        if (accessFailure is not null)
        {
            return Result.Failure<HotelContentDto>(accessFailure.Error);
        }

        HotelContentDto? content = await _repository.GetHotelContentAsync(hotelId, cancellationToken);
        return content is null
            ? Result.Failure<HotelContentDto>(HotelManagementErrors.HotelNotFound)
            : Result.Success(content);
    }

    public async Task<Result<HotelContentDto>> UpdateHotelContentAsync(
        Guid hotelId,
        UpdateHotelContentRequest request,
        CancellationToken cancellationToken)
    {
        Result? accessFailure = await EnsureOwnedHotelAsync(hotelId, cancellationToken);
        if (accessFailure is not null)
        {
            return Result.Failure<HotelContentDto>(accessFailure.Error);
        }

        ValidationResult validationResult = await _updateHotelContentValidator.ValidateAsync(request, cancellationToken);
        if (!validationResult.IsValid)
        {
            return Result.Failure<HotelContentDto>(
                ValidationErrorFormatter.ToResultError("HotelManagement.InvalidHotelContent", validationResult));
        }

        HotelContentPersistenceResult persistenceResult = await _repository.ReplaceHotelContentAsync(
            hotelId,
            request,
            _currentUserService.UserId!.Value,
            cancellationToken);

        return persistenceResult.Status switch
        {
            HotelContentPersistenceStatus.Success => Result.Success(persistenceResult.Content!),
            HotelContentPersistenceStatus.LockUnavailable =>
                Result.Failure<HotelContentDto>(HotelManagementErrors.LockUnavailable),
            _ => Result.Failure<HotelContentDto>(HotelManagementErrors.HotelNotFound)
        };
    }

    public async Task<Result<IReadOnlyCollection<HotelStaffMemberDto>>> GetStaffAsync(Guid hotelId, CancellationToken cancellationToken)
    {
        Result? accessFailure = await EnsureOwnedHotelAsync(hotelId, cancellationToken);
        if (accessFailure is not null)
        {
            return Result.Failure<IReadOnlyCollection<HotelStaffMemberDto>>(accessFailure.Error);
        }

        IReadOnlyCollection<HotelStaffMemberDto> staff = await _repository.GetStaffAsync(hotelId, cancellationToken);

        return Result.Success(staff);
    }

    public async Task<Result<IReadOnlyCollection<HotelStaffMemberDto>>> GetOperationStaffAsync(Guid hotelId, CancellationToken cancellationToken)
    {
        UserRoleCode[] staffViewerRoles = { UserRoleCode.HotelManager, UserRoleCode.PropertyOwner };
        Result? accessFailure = await EnsureHotelOperationAccessAsync(hotelId, staffViewerRoles, cancellationToken);
        if (accessFailure is not null)
        {
            return Result.Failure<IReadOnlyCollection<HotelStaffMemberDto>>(accessFailure.Error);
        }

        IReadOnlyCollection<HotelStaffMemberDto> staff = await _repository.GetStaffAsync(hotelId, cancellationToken);

        return Result.Success(staff);
    }

    public async Task<Result<HotelStaffMemberDto>> CreateStaffAsync(Guid hotelId, CreateHotelStaffRequest request, CancellationToken cancellationToken)
    {
        Result<UserRoleCode> managerRole = await GetStaffManagementRoleAsync(hotelId, cancellationToken);
        if (managerRole.IsFailure)
        {
            return Result.Failure<HotelStaffMemberDto>(managerRole.Error);
        }

        ValidationResult validationResult = await _createHotelStaffValidator.ValidateAsync(request, cancellationToken);
        if (!validationResult.IsValid)
        {
            return Result.Failure<HotelStaffMemberDto>(
                ValidationErrorFormatter.ToResultError("HotelManagement.InvalidStaffAccount", validationResult));
        }

        if (!CanManageRole(managerRole.Value, request.Role))
        {
            return Result.Failure<HotelStaffMemberDto>(HotelManagementErrors.ManagerRoleManagementForbidden);
        }

        string normalizedEmail = request.Email.Trim().ToLowerInvariant();
        string normalizedPhone = request.PhoneNumber.Trim();

        if (await _repository.EmailExistsAsync(normalizedEmail, cancellationToken))
        {
            return Result.Failure<HotelStaffMemberDto>(HotelManagementErrors.DuplicateStaffEmail);
        }

        if (await _repository.PhoneNumberExistsAsync(normalizedPhone, cancellationToken))
        {
            return Result.Failure<HotelStaffMemberDto>(HotelManagementErrors.DuplicateStaffPhoneNumber);
        }

        UserRole? role = await _repository.GetRoleAsync(request.Role, cancellationToken);
        if (role is null)
        {
            return Result.Failure<HotelStaffMemberDto>(HotelManagementErrors.InvalidStaffRole);
        }

        UserAccount userAccount = new(
            Guid.NewGuid(),
            normalizedEmail,
            _passwordHasher.HashPassword(request.Password),
            request.FullName.Trim(),
            normalizedPhone);

        StaffLifecyclePersistenceResult persistenceResult = await _repository.CreateStaffAsync(
            hotelId,
            userAccount,
            role.Id,
            _currentUserService.UserId!.Value,
            request.Role,
            cancellationToken);

        return MapStaffPersistenceResult(persistenceResult);
    }

    public async Task<Result<HotelStaffMemberDto>> AttachStaffAsync(
        Guid hotelId,
        AttachHotelStaffRequest request,
        CancellationToken cancellationToken)
    {
        Result<UserRoleCode> managerRole = await GetStaffManagementRoleAsync(hotelId, cancellationToken);
        if (managerRole.IsFailure)
        {
            return Result.Failure<HotelStaffMemberDto>(managerRole.Error);
        }

        ValidationResult validationResult = await _attachHotelStaffValidator.ValidateAsync(request, cancellationToken);
        if (!validationResult.IsValid)
        {
            return Result.Failure<HotelStaffMemberDto>(
                ValidationErrorFormatter.ToResultError("HotelManagement.InvalidStaffAttachment", validationResult));
        }
        if (!CanManageRole(managerRole.Value, request.Role))
        {
            return Result.Failure<HotelStaffMemberDto>(HotelManagementErrors.ManagerRoleManagementForbidden);
        }

        UserRole? role = await _repository.GetRoleAsync(request.Role, cancellationToken);
        if (role is null)
        {
            return Result.Failure<HotelStaffMemberDto>(HotelManagementErrors.InvalidStaffRole);
        }

        StaffLifecyclePersistenceResult persistenceResult = await _repository.AttachStaffAsync(
            hotelId,
            request.Email.Trim().ToLowerInvariant(),
            role.Id,
            _currentUserService.UserId!.Value,
            request.Role,
            cancellationToken);

        return MapStaffPersistenceResult(persistenceResult);
    }

    public async Task<Result<HotelStaffMemberDto>> UpdateStaffAssignmentAsync(
        Guid hotelId,
        Guid assignmentId,
        UpdateHotelStaffAssignmentRequest request,
        CancellationToken cancellationToken)
    {
        Result<UserRoleCode> managerRole = await GetStaffManagementRoleAsync(hotelId, cancellationToken);
        if (managerRole.IsFailure)
        {
            return Result.Failure<HotelStaffMemberDto>(managerRole.Error);
        }

        ValidationResult validationResult = await _updateHotelStaffAssignmentValidator.ValidateAsync(request, cancellationToken);
        if (!validationResult.IsValid)
        {
            return Result.Failure<HotelStaffMemberDto>(
                ValidationErrorFormatter.ToResultError("HotelManagement.InvalidStaffUpdate", validationResult));
        }
        if (request.Role.HasValue && !CanManageRole(managerRole.Value, request.Role.Value))
        {
            return Result.Failure<HotelStaffMemberDto>(HotelManagementErrors.ManagerRoleManagementForbidden);
        }

        Guid? targetRoleId = null;
        if (request.Role.HasValue)
        {
            UserRole? role = await _repository.GetRoleAsync(request.Role.Value, cancellationToken);
            if (role is null)
            {
                return Result.Failure<HotelStaffMemberDto>(HotelManagementErrors.InvalidStaffRole);
            }

            targetRoleId = role.Id;
        }

        StaffLifecyclePersistenceResult persistenceResult = await _repository.UpdateStaffAssignmentAsync(
            hotelId,
            assignmentId,
            targetRoleId,
            request.Role,
            request.IsActive,
            _currentUserService.UserId!.Value,
            cancellationToken);

        return MapStaffPersistenceResult(persistenceResult);
    }

    public async Task<Result<RoomTypeDto>> CreateRoomTypeAsync(Guid hotelId, CreateRoomTypeRequest request, CancellationToken cancellationToken)
    {
        Result? accessFailure = await EnsureOwnedHotelAsync(hotelId, cancellationToken);
        if (accessFailure is not null)
        {
            return Result.Failure<RoomTypeDto>(accessFailure.Error);
        }

        ValidationResult validationResult = await _createRoomTypeValidator.ValidateAsync(request, cancellationToken);
        if (!validationResult.IsValid)
        {
            return Result.Failure<RoomTypeDto>(ValidationErrorFormatter.ToResultError("HotelManagement.InvalidRoomType", validationResult));
        }

        RoomType roomType = new(
            Guid.NewGuid(),
            hotelId,
            request.Name,
            request.AdultCapacity,
            request.ChildCapacity,
            request.BasePricePerNight,
            request.Description,
            request.Facilities);
        await _repository.AddRoomTypeAsync(roomType, cancellationToken);

        return ToRoomTypeDto(roomType);
    }

    public async Task<Result<IReadOnlyCollection<RoomTypeDto>>> GetRoomTypesAsync(Guid hotelId, CancellationToken cancellationToken)
    {
        Result? accessFailure = await EnsureOwnedHotelAsync(hotelId, cancellationToken);
        if (accessFailure is not null)
        {
            return Result.Failure<IReadOnlyCollection<RoomTypeDto>>(accessFailure.Error);
        }

        IReadOnlyCollection<RoomType> roomTypes = await _repository.GetRoomTypesAsync(hotelId, cancellationToken);

        return roomTypes.Select(ToRoomTypeDto).ToArray();
    }

    public async Task<Result<IReadOnlyCollection<RoomTypeDto>>> GetOperationRoomTypesAsync(Guid hotelId, CancellationToken cancellationToken)
    {
        UserRoleCode[] operationRoles =
        {
            UserRoleCode.PropertyOwner,
            UserRoleCode.HotelManager,
            UserRoleCode.Receptionist,
            UserRoleCode.HousekeepingStaff,
            UserRoleCode.MaintenanceStaff
        };
        Result? accessFailure = await EnsureHotelOperationAccessAsync(hotelId, operationRoles, cancellationToken);
        if (accessFailure is not null)
        {
            return Result.Failure<IReadOnlyCollection<RoomTypeDto>>(accessFailure.Error);
        }

        IReadOnlyCollection<RoomType> roomTypes = await _repository.GetRoomTypesAsync(hotelId, cancellationToken);

        return roomTypes.Select(ToRoomTypeDto).ToArray();
    }

    public async Task<Result<RoomTypeDto>> UpdateRoomTypeAsync(Guid hotelId, Guid roomTypeId, UpdateRoomTypeRequest request, CancellationToken cancellationToken)
    {
        Result? accessFailure = await EnsureOwnedHotelAsync(hotelId, cancellationToken);
        if (accessFailure is not null)
        {
            return Result.Failure<RoomTypeDto>(accessFailure.Error);
        }

        ValidationResult validationResult = await _updateRoomTypeValidator.ValidateAsync(request, cancellationToken);
        if (!validationResult.IsValid)
        {
            return Result.Failure<RoomTypeDto>(ValidationErrorFormatter.ToResultError("HotelManagement.InvalidRoomType", validationResult));
        }

        RoomType? roomType = await _repository.GetRoomTypeAsync(hotelId, roomTypeId, cancellationToken);
        if (roomType is null)
        {
            return Result.Failure<RoomTypeDto>(HotelManagementErrors.RoomTypeNotFound);
        }

        roomType.UpdateDetails(
            request.Name,
            request.AdultCapacity,
            request.ChildCapacity,
            request.BasePricePerNight,
            request.Description,
            request.Facilities);
        await _repository.SaveChangesAsync(cancellationToken);

        return ToRoomTypeDto(roomType);
    }

    public async Task<Result> DeactivateRoomTypeAsync(Guid hotelId, Guid roomTypeId, CancellationToken cancellationToken)
    {
        Result? accessFailure = await EnsureOwnedHotelAsync(hotelId, cancellationToken);
        if (accessFailure is not null)
        {
            return accessFailure;
        }

        RoomType? roomType = await _repository.GetRoomTypeAsync(hotelId, roomTypeId, cancellationToken);
        if (roomType is null)
        {
            return Result.Failure(HotelManagementErrors.RoomTypeNotFound);
        }

        if (await _repository.RoomTypeHasActiveFutureBookingsAsync(roomTypeId, _dateTimeProvider.Today, cancellationToken))
        {
            return Result.Failure(HotelManagementErrors.RoomTypeHasFutureBookings);
        }

        roomType.Deactivate();
        await _repository.SaveChangesAsync(cancellationToken);

        return Result.Success();
    }

    public async Task<Result<PhysicalRoomDto>> CreatePhysicalRoomAsync(Guid hotelId, CreatePhysicalRoomRequest request, CancellationToken cancellationToken)
    {
        Result? accessFailure = await EnsureOwnedHotelAsync(hotelId, cancellationToken);
        if (accessFailure is not null)
        {
            return Result.Failure<PhysicalRoomDto>(accessFailure.Error);
        }

        ValidationResult validationResult = await _createPhysicalRoomValidator.ValidateAsync(request, cancellationToken);
        if (!validationResult.IsValid)
        {
            return Result.Failure<PhysicalRoomDto>(ValidationErrorFormatter.ToResultError("HotelManagement.InvalidPhysicalRoom", validationResult));
        }

        PhysicalRoomPersistenceResult persistenceResult = await _repository.CreatePhysicalRoomAsync(
            hotelId,
            request.RoomTypeId,
            request.RoomNumber,
            request.InitialStatus,
            request.Floor,
            request.Notes,
            cancellationToken);

        return ToPhysicalRoomResult(persistenceResult);
    }

    public async Task<Result<IReadOnlyCollection<PhysicalRoomDto>>> GetPhysicalRoomsAsync(Guid hotelId, Guid? roomTypeId, CancellationToken cancellationToken)
    {
        Result? accessFailure = await EnsureOwnedHotelAsync(hotelId, cancellationToken);
        if (accessFailure is not null)
        {
            return Result.Failure<IReadOnlyCollection<PhysicalRoomDto>>(accessFailure.Error);
        }

        IReadOnlyCollection<PhysicalRoom> physicalRooms = await _repository.GetPhysicalRoomsAsync(hotelId, roomTypeId, cancellationToken);

        return physicalRooms.Select(ToPhysicalRoomDto).ToArray();
    }

    public async Task<Result<PhysicalRoomDto>> UpdatePhysicalRoomAsync(Guid hotelId, Guid physicalRoomId, UpdatePhysicalRoomRequest request, CancellationToken cancellationToken)
    {
        Result? accessFailure = await EnsureOwnedHotelAsync(hotelId, cancellationToken);
        if (accessFailure is not null)
        {
            return Result.Failure<PhysicalRoomDto>(accessFailure.Error);
        }

        ValidationResult validationResult = await _updatePhysicalRoomValidator.ValidateAsync(request, cancellationToken);
        if (!validationResult.IsValid)
        {
            return Result.Failure<PhysicalRoomDto>(ValidationErrorFormatter.ToResultError("HotelManagement.InvalidPhysicalRoom", validationResult));
        }

        PhysicalRoomPersistenceResult persistenceResult = await _repository.UpdatePhysicalRoomAsync(
            hotelId,
            physicalRoomId,
            request.RoomNumber,
            request.Status,
            request.Floor,
            request.Notes,
            cancellationToken);

        return ToPhysicalRoomResult(persistenceResult);
    }

    private Result? EnsurePropertyOwner()
    {
        if (_currentUserService.UserId is null || !_currentUserService.Roles.Contains(UserRoleCode.PropertyOwner))
        {
            return Result.Failure(HotelManagementErrors.Forbidden);
        }

        return null;
    }

    private async Task<Result?> EnsureOwnedHotelAsync(Guid hotelId, CancellationToken cancellationToken)
    {
        Result? roleFailure = EnsurePropertyOwner();
        if (roleFailure is not null)
        {
            return roleFailure;
        }

        bool ownsHotel = await _repository.UserOwnsHotelAsync(_currentUserService.UserId!.Value, hotelId, cancellationToken);
        return ownsHotel ? null : Result.Failure(HotelManagementErrors.Forbidden);
    }

    private async Task<Result?> EnsureHotelOperationAccessAsync(
        Guid hotelId,
        IReadOnlyCollection<UserRoleCode> allowedRoles,
        CancellationToken cancellationToken)
    {
        if (_currentUserService.UserId is null)
        {
            return Result.Failure(HotelManagementErrors.Forbidden);
        }

        return await _hotelAccessAuthorizer.HasAccessAsync(hotelId, allowedRoles, cancellationToken)
            ? null
            : Result.Failure(HotelManagementErrors.Forbidden);
    }

    private async Task<Result<UserRoleCode>> GetStaffManagementRoleAsync(
        Guid hotelId,
        CancellationToken cancellationToken)
    {
        if (_currentUserService.UserId is null)
        {
            return Result.Failure<UserRoleCode>(HotelManagementErrors.Forbidden);
        }

        if (await _repository.UserOwnsHotelAsync(_currentUserService.UserId.Value, hotelId, cancellationToken))
        {
            return Result.Success(UserRoleCode.PropertyOwner);
        }

        return await _hotelAccessAuthorizer.HasAccessAsync(
            hotelId,
            new[] { UserRoleCode.HotelManager },
            cancellationToken)
            ? Result.Success(UserRoleCode.HotelManager)
            : Result.Failure<UserRoleCode>(HotelManagementErrors.Forbidden);
    }

    private static bool CanManageRole(UserRoleCode managerRole, UserRoleCode targetRole)
    {
        if (managerRole == UserRoleCode.PropertyOwner)
        {
            return targetRole is UserRoleCode.HotelManager or UserRoleCode.Receptionist or
                UserRoleCode.HousekeepingStaff or UserRoleCode.MaintenanceStaff;
        }

        return managerRole == UserRoleCode.HotelManager &&
            targetRole is UserRoleCode.Receptionist or UserRoleCode.HousekeepingStaff or UserRoleCode.MaintenanceStaff;
    }

    private static Result<HotelStaffMemberDto> MapStaffPersistenceResult(StaffLifecyclePersistenceResult result)
    {
        return result.Status switch
        {
            StaffLifecyclePersistenceStatus.Success => Result.Success(result.Staff!),
            StaffLifecyclePersistenceStatus.UserNotFound => Result.Failure<HotelStaffMemberDto>(HotelManagementErrors.StaffUserNotFound),
            StaffLifecyclePersistenceStatus.AssignmentNotFound => Result.Failure<HotelStaffMemberDto>(HotelManagementErrors.StaffNotFound),
            StaffLifecyclePersistenceStatus.DuplicateAssignment => Result.Failure<HotelStaffMemberDto>(HotelManagementErrors.DuplicateStaffAssignment),
            StaffLifecyclePersistenceStatus.DuplicateEmail => Result.Failure<HotelStaffMemberDto>(HotelManagementErrors.DuplicateStaffEmail),
            StaffLifecyclePersistenceStatus.DuplicatePhoneNumber => Result.Failure<HotelStaffMemberDto>(HotelManagementErrors.DuplicateStaffPhoneNumber),
            StaffLifecyclePersistenceStatus.SystemAccountForbidden => Result.Failure<HotelStaffMemberDto>(HotelManagementErrors.StaffSystemAccountForbidden),
            StaffLifecyclePersistenceStatus.PlatformAdministratorForbidden => Result.Failure<HotelStaffMemberDto>(HotelManagementErrors.StaffPlatformAdministratorForbidden),
            StaffLifecyclePersistenceStatus.AccountInactive => Result.Failure<HotelStaffMemberDto>(HotelManagementErrors.StaffAccountInactive),
            StaffLifecyclePersistenceStatus.OpenTasks => Result.Failure<HotelStaffMemberDto>(HotelManagementErrors.StaffHasOpenTasks),
            StaffLifecyclePersistenceStatus.LockUnavailable => Result.Failure<HotelStaffMemberDto>(HotelManagementErrors.LockUnavailable),
            StaffLifecyclePersistenceStatus.SelfManagementForbidden => Result.Failure<HotelStaffMemberDto>(HotelManagementErrors.SelfManagementForbidden),
            StaffLifecyclePersistenceStatus.ManagerRoleManagementForbidden => Result.Failure<HotelStaffMemberDto>(HotelManagementErrors.ManagerRoleManagementForbidden),
            StaffLifecyclePersistenceStatus.InactiveAssignment => Result.Failure<HotelStaffMemberDto>(HotelManagementErrors.InactiveStaffAssignment),
            StaffLifecyclePersistenceStatus.ActorAccessRevoked => Result.Failure<HotelStaffMemberDto>(HotelManagementErrors.Forbidden),
            _ => Result.Failure<HotelStaffMemberDto>(HotelManagementErrors.StaffNotFound)
        };
    }

    private static HotelDto ToHotelDto(HotelProperty hotel)
    {
        return new HotelDto(
            hotel.Id,
            hotel.OwnerUserAccountId,
            hotel.Name,
            hotel.City,
            hotel.AddressLine,
            hotel.ContactEmail,
            hotel.ContactPhone,
            hotel.Description,
            hotel.ApprovalStatus,
            hotel.PublicationStatus,
            hotel.RequiresRoomInspection,
            hotel.CreatedAtUtc);
    }

    private static RoomTypeDto ToRoomTypeDto(RoomType roomType)
    {
        return new RoomTypeDto(
            roomType.Id,
            roomType.HotelId,
            roomType.Name,
            roomType.AdultCapacity,
            roomType.ChildCapacity,
            roomType.BasePricePerNight,
            roomType.Description,
            roomType.Facilities,
            roomType.Status);
    }

    private static PhysicalRoomDto ToPhysicalRoomDto(PhysicalRoom physicalRoom)
    {
        return new PhysicalRoomDto(
            physicalRoom.Id,
            physicalRoom.HotelId,
            physicalRoom.RoomTypeId,
            physicalRoom.RoomNumber,
            physicalRoom.Floor,
            physicalRoom.Notes,
            physicalRoom.Status);
    }

    private static Result<PhysicalRoomDto> ToPhysicalRoomResult(PhysicalRoomPersistenceResult result)
    {
        return result.Status switch
        {
            PhysicalRoomPersistenceStatus.Success => Result.Success(ToPhysicalRoomDto(result.PhysicalRoom!)),
            PhysicalRoomPersistenceStatus.RoomTypeNotFound => Result.Failure<PhysicalRoomDto>(HotelManagementErrors.RoomTypeNotFound),
            PhysicalRoomPersistenceStatus.PhysicalRoomNotFound => Result.Failure<PhysicalRoomDto>(HotelManagementErrors.PhysicalRoomNotFound),
            PhysicalRoomPersistenceStatus.DuplicateRoomNumber => Result.Failure<PhysicalRoomDto>(HotelManagementErrors.DuplicateRoomNumber),
            PhysicalRoomPersistenceStatus.RoomIsOccupied => Result.Failure<PhysicalRoomDto>(HotelManagementErrors.RoomIsOccupied),
            PhysicalRoomPersistenceStatus.InvalidRoomStatus => Result.Failure<PhysicalRoomDto>(HotelManagementErrors.OperationalLifecycleActive),
            PhysicalRoomPersistenceStatus.OperationalLifecycleActive => Result.Failure<PhysicalRoomDto>(HotelManagementErrors.OperationalLifecycleActive),
            PhysicalRoomPersistenceStatus.LockUnavailable => Result.Failure<PhysicalRoomDto>(HotelManagementErrors.LockUnavailable),
            _ => Result.Failure<PhysicalRoomDto>(HotelManagementErrors.PhysicalRoomNotFound)
        };
    }
}
