using FluentAssertions;
using HotelMarketplace.Domain.Entities;
using HotelMarketplace.SharedKernel.Exceptions;
using Xunit;

namespace HotelMarketplace.Domain.UnitTests;

public sealed class CustomerEngagementTests
{
    [Fact]
    public void NotificationReadIsIdempotent()
    {
        NotificationRecord notification = new(
            Guid.NewGuid(),
            Guid.NewGuid(),
            "BookingConfirmed",
            nameof(Booking),
            Guid.NewGuid(),
            "Booking confirmed.");
        DateTime firstReadAtUtc = new(2026, 7, 19, 12, 0, 0, DateTimeKind.Utc);

        notification.MarkRead(firstReadAtUtc);
        notification.MarkRead(firstReadAtUtc.AddMinutes(5));

        notification.ReadAtUtc.Should().Be(firstReadAtUtc);
    }

    [Fact]
    public void SavedHotelRejectsLocalCreationTime()
    {
        Func<SavedHotel> action = () => new SavedHotel(
            Guid.NewGuid(),
            Guid.NewGuid(),
            Guid.NewGuid(),
            DateTime.SpecifyKind(DateTime.Now, DateTimeKind.Local));

        action.Should().Throw<DomainException>()
            .Where(exception => exception.Code == "SavedHotel.InvalidCreatedTime");
    }
}
