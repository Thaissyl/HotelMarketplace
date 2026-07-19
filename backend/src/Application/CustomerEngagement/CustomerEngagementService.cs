using HotelMarketplace.Application.CustomerEngagement.Dtos;
using HotelMarketplace.Application.Security;
using HotelMarketplace.SharedKernel.Results;
using HotelMarketplace.SharedKernel.Time;

namespace HotelMarketplace.Application.CustomerEngagement;

public sealed class CustomerEngagementService : ICustomerEngagementService
{
    private readonly ICurrentUserService _currentUserService;
    private readonly ICustomerEngagementRepository _repository;
    private readonly IDateTimeProvider _dateTimeProvider;

    public CustomerEngagementService(
        ICurrentUserService currentUserService,
        ICustomerEngagementRepository repository,
        IDateTimeProvider dateTimeProvider)
    {
        _currentUserService = currentUserService;
        _repository = repository;
        _dateTimeProvider = dateTimeProvider;
    }

    public async Task<Result<IReadOnlyCollection<SavedHotelDto>>> GetSavedHotelsAsync(CancellationToken cancellationToken)
    {
        if (_currentUserService.UserId is not Guid userId)
        {
            return Result.Failure<IReadOnlyCollection<SavedHotelDto>>(CustomerEngagementErrors.Unauthenticated);
        }

        return Result.Success(await _repository.GetSavedHotelsAsync(userId, cancellationToken));
    }

    public async Task<Result<SavedHotelDto>> SaveHotelAsync(Guid hotelId, CancellationToken cancellationToken)
    {
        if (_currentUserService.UserId is not Guid userId)
        {
            return Result.Failure<SavedHotelDto>(CustomerEngagementErrors.Unauthenticated);
        }

        SavedHotelDto? savedHotel = await _repository.SaveHotelAsync(
            userId,
            hotelId,
            _dateTimeProvider.UtcNow,
            cancellationToken);
        return savedHotel is null
            ? Result.Failure<SavedHotelDto>(CustomerEngagementErrors.HotelNotFound)
            : Result.Success(savedHotel);
    }

    public async Task<Result> RemoveSavedHotelAsync(Guid hotelId, CancellationToken cancellationToken)
    {
        if (_currentUserService.UserId is not Guid userId)
        {
            return Result.Failure(CustomerEngagementErrors.Unauthenticated);
        }

        await _repository.RemoveSavedHotelAsync(userId, hotelId, cancellationToken);
        return Result.Success();
    }

    public async Task<Result<IReadOnlyCollection<AccountNotificationDto>>> GetNotificationsAsync(int limit, CancellationToken cancellationToken)
    {
        if (_currentUserService.UserId is not Guid userId)
        {
            return Result.Failure<IReadOnlyCollection<AccountNotificationDto>>(CustomerEngagementErrors.Unauthenticated);
        }

        return Result.Success(await _repository.GetNotificationsAsync(userId, Math.Clamp(limit, 1, 100), cancellationToken));
    }

    public async Task<Result> MarkNotificationReadAsync(Guid notificationId, CancellationToken cancellationToken)
    {
        if (_currentUserService.UserId is not Guid userId)
        {
            return Result.Failure(CustomerEngagementErrors.Unauthenticated);
        }

        bool found = await _repository.MarkNotificationReadAsync(userId, notificationId, _dateTimeProvider.UtcNow, cancellationToken);
        return found ? Result.Success() : Result.Failure(CustomerEngagementErrors.NotificationNotFound);
    }

    public async Task<Result<int>> MarkAllNotificationsReadAsync(CancellationToken cancellationToken)
    {
        if (_currentUserService.UserId is not Guid userId)
        {
            return Result.Failure<int>(CustomerEngagementErrors.Unauthenticated);
        }

        return Result.Success(await _repository.MarkAllNotificationsReadAsync(userId, _dateTimeProvider.UtcNow, cancellationToken));
    }
}
