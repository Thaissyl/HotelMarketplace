using FluentValidation;
using FluentValidation.Results;
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
    private readonly IDateTimeProvider _dateTimeProvider;
    private readonly IValidator<RegisterHotelRequest> _registerHotelValidator;
    private readonly IValidator<UpdateHotelProfileRequest> _updateHotelProfileValidator;
    private readonly IValidator<CreateRoomTypeRequest> _createRoomTypeValidator;
    private readonly IValidator<UpdateRoomTypeRequest> _updateRoomTypeValidator;
    private readonly IValidator<CreatePhysicalRoomRequest> _createPhysicalRoomValidator;
    private readonly IValidator<UpdatePhysicalRoomRequest> _updatePhysicalRoomValidator;

    public HotelManagementService(
        IHotelManagementRepository repository,
        ICurrentUserService currentUserService,
        IDateTimeProvider dateTimeProvider,
        IValidator<RegisterHotelRequest> registerHotelValidator,
        IValidator<UpdateHotelProfileRequest> updateHotelProfileValidator,
        IValidator<CreateRoomTypeRequest> createRoomTypeValidator,
        IValidator<UpdateRoomTypeRequest> updateRoomTypeValidator,
        IValidator<CreatePhysicalRoomRequest> createPhysicalRoomValidator,
        IValidator<UpdatePhysicalRoomRequest> updatePhysicalRoomValidator)
    {
        _repository = repository;
        _currentUserService = currentUserService;
        _dateTimeProvider = dateTimeProvider;
        _registerHotelValidator = registerHotelValidator;
        _updateHotelProfileValidator = updateHotelProfileValidator;
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
        await _repository.SaveChangesAsync(cancellationToken);

        return ToHotelDto(hotel);
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

        RoomType roomType = new(Guid.NewGuid(), hotelId, request.Name, request.AdultCapacity, request.ChildCapacity, request.BasePricePerNight, request.Description);
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

        roomType.UpdateDetails(request.Name, request.AdultCapacity, request.ChildCapacity, request.BasePricePerNight, request.Description);
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

        RoomType? roomType = await _repository.GetRoomTypeAsync(hotelId, request.RoomTypeId, cancellationToken);
        if (roomType is null)
        {
            return Result.Failure<PhysicalRoomDto>(HotelManagementErrors.RoomTypeNotFound);
        }

        if (await _repository.RoomNumberExistsAsync(hotelId, request.RoomNumber, excludedPhysicalRoomId: null, cancellationToken))
        {
            return Result.Failure<PhysicalRoomDto>(HotelManagementErrors.DuplicateRoomNumber);
        }

        PhysicalRoom physicalRoom = new(Guid.NewGuid(), hotelId, request.RoomTypeId, request.RoomNumber, request.InitialStatus);
        await _repository.AddPhysicalRoomAsync(physicalRoom, cancellationToken);

        return ToPhysicalRoomDto(physicalRoom);
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

        PhysicalRoom? physicalRoom = await _repository.GetPhysicalRoomAsync(hotelId, physicalRoomId, cancellationToken);
        if (physicalRoom is null)
        {
            return Result.Failure<PhysicalRoomDto>(HotelManagementErrors.PhysicalRoomNotFound);
        }

        if (request.Status == RoomOperationalStatus.Inactive && physicalRoom.Status == RoomOperationalStatus.Occupied)
        {
            return Result.Failure<PhysicalRoomDto>(HotelManagementErrors.RoomIsOccupied);
        }

        if (await _repository.RoomNumberExistsAsync(hotelId, request.RoomNumber, physicalRoomId, cancellationToken))
        {
            return Result.Failure<PhysicalRoomDto>(HotelManagementErrors.DuplicateRoomNumber);
        }

        physicalRoom.Rename(request.RoomNumber);
        physicalRoom.ChangeSetupStatus(request.Status);
        await _repository.SaveChangesAsync(cancellationToken);

        return ToPhysicalRoomDto(physicalRoom);
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
            roomType.Status);
    }

    private static PhysicalRoomDto ToPhysicalRoomDto(PhysicalRoom physicalRoom)
    {
        return new PhysicalRoomDto(
            physicalRoom.Id,
            physicalRoom.HotelId,
            physicalRoom.RoomTypeId,
            physicalRoom.RoomNumber,
            physicalRoom.Status);
    }
}
