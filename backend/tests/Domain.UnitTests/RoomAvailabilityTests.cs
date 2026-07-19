using FluentAssertions;
using HotelMarketplace.Domain.Entities;
using HotelMarketplace.Domain.Enums;
using HotelMarketplace.SharedKernel.Exceptions;
using Xunit;

namespace HotelMarketplace.Domain.UnitTests;

public sealed class RoomAvailabilityTests
{
    [Theory]
    [InlineData(AvailabilityStatus.Closed)]
    [InlineData(AvailabilityStatus.Blocked)]
    public void BlockingIntervalRequiresReason(AvailabilityStatus status)
    {
        Action action = () => _ = new RoomAvailability(
            Guid.NewGuid(),
            Guid.NewGuid(),
            Guid.NewGuid(),
            new DateOnly(2026, 8, 1),
            new DateOnly(2026, 8, 2),
            status,
            reason: " ");

        action.Should().Throw<DomainException>()
            .Where(exception => exception.Code == "Domain.RequiredField");
    }

    [Fact]
    public void OpenIntervalCannotBePersisted()
    {
        Action action = () => _ = new RoomAvailability(
            Guid.NewGuid(),
            Guid.NewGuid(),
            Guid.NewGuid(),
            new DateOnly(2026, 8, 1),
            new DateOnly(2026, 8, 2),
            AvailabilityStatus.Open,
            reason: "Open");

        action.Should().Throw<DomainException>()
            .Where(exception => exception.Code == "RoomAvailability.OpenIntervalsAreNotPersisted");
    }
}
