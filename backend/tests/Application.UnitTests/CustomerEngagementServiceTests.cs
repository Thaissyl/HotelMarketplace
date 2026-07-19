using FluentAssertions;
using HotelMarketplace.Application.CustomerEngagement;
using HotelMarketplace.Application.CustomerEngagement.Dtos;
using HotelMarketplace.Application.Security;
using HotelMarketplace.Domain.Enums;
using HotelMarketplace.SharedKernel.Time;
using Xunit;

namespace HotelMarketplace.Application.UnitTests;

public sealed class CustomerEngagementServiceTests
{
    [Fact]
    public async Task NotificationLimitIsClampedToServerMaximum()
    {
        FakeRepository repository = new();
        CustomerEngagementService service = new(
            new FakeCurrentUser(Guid.NewGuid()),
            repository,
            new FakeDateTimeProvider());

        await service.GetNotificationsAsync(500, CancellationToken.None);

        repository.LastNotificationLimit.Should().Be(100);
    }

    [Fact]
    public async Task MissingCurrentUserFailsBeforeRepositoryAccess()
    {
        FakeRepository repository = new();
        CustomerEngagementService service = new(
            new FakeCurrentUser(null),
            repository,
            new FakeDateTimeProvider());

        var result = await service.GetSavedHotelsAsync(CancellationToken.None);

        result.IsFailure.Should().BeTrue();
        result.Error.Code.Should().Be("CustomerEngagement.Unauthenticated");
        repository.SavedHotelsRequested.Should().BeFalse();
    }

    private sealed class FakeCurrentUser : ICurrentUserService
    {
        public FakeCurrentUser(Guid? userId) => UserId = userId;
        public bool IsAuthenticated => UserId.HasValue;
        public Guid? UserId { get; }
        public string? Email => null;
        public IReadOnlyCollection<UserRoleCode> Roles => Array.Empty<UserRoleCode>();
        public IReadOnlyCollection<Guid> HotelIds => Array.Empty<Guid>();
        public IReadOnlyCollection<HotelRoleAccess> HotelRoleAccesses => Array.Empty<HotelRoleAccess>();
    }

    private sealed class FakeDateTimeProvider : IDateTimeProvider
    {
        public DateTime UtcNow => new(2026, 7, 19, 12, 0, 0, DateTimeKind.Utc);
        public DateOnly Today => DateOnly.FromDateTime(UtcNow);
    }

    private sealed class FakeRepository : ICustomerEngagementRepository
    {
        public int LastNotificationLimit { get; private set; }
        public bool SavedHotelsRequested { get; private set; }

        public Task<IReadOnlyCollection<SavedHotelDto>> GetSavedHotelsAsync(Guid userAccountId, CancellationToken cancellationToken)
        {
            SavedHotelsRequested = true;
            return Task.FromResult<IReadOnlyCollection<SavedHotelDto>>(Array.Empty<SavedHotelDto>());
        }

        public Task<SavedHotelDto?> SaveHotelAsync(Guid userAccountId, Guid hotelId, DateTime utcNow, CancellationToken cancellationToken) => Task.FromResult<SavedHotelDto?>(null);
        public Task RemoveSavedHotelAsync(Guid userAccountId, Guid hotelId, CancellationToken cancellationToken) => Task.CompletedTask;

        public Task<IReadOnlyCollection<AccountNotificationDto>> GetNotificationsAsync(Guid userAccountId, int limit, CancellationToken cancellationToken)
        {
            LastNotificationLimit = limit;
            return Task.FromResult<IReadOnlyCollection<AccountNotificationDto>>(Array.Empty<AccountNotificationDto>());
        }

        public Task<bool> MarkNotificationReadAsync(Guid userAccountId, Guid notificationId, DateTime utcNow, CancellationToken cancellationToken) => Task.FromResult(false);
        public Task<int> MarkAllNotificationsReadAsync(Guid userAccountId, DateTime utcNow, CancellationToken cancellationToken) => Task.FromResult(0);
    }
}
