using FluentAssertions;
using HotelMarketplace.Domain.Entities;
using HotelMarketplace.Domain.Enums;
using HotelMarketplace.SharedKernel.Exceptions;
using Xunit;

namespace HotelMarketplace.Domain.UnitTests;

public sealed class BookingLifecycleTests
{
    [Theory]
    [InlineData(PaymentMode.PlatformCollect, BookingStatus.PendingPayment)]
    [InlineData(PaymentMode.PayAtProperty, BookingStatus.Confirmed)]
    public void CancelFromCancellableStateRecordsEvidence(
        PaymentMode paymentMode,
        BookingStatus expectedInitialStatus)
    {
        Booking booking = CreateBooking(paymentMode);
        booking.Status.Should().Be(expectedInitialStatus);
        DateTime cancelledAtUtc = new(2026, 7, 19, 10, 0, 0, DateTimeKind.Utc);

        booking.Cancel("Customer changed travel plans", cancelledAtUtc);

        booking.Status.Should().Be(BookingStatus.Cancelled);
        booking.CancellationReason.Should().Be("Customer changed travel plans");
        booking.CancelledAtUtc.Should().Be(cancelledAtUtc);
        booking.PaymentExpiresAtUtc.Should().BeNull();
    }

    [Fact]
    public void CancelCheckedInBookingIsRejected()
    {
        Booking booking = CreateBooking(PaymentMode.PayAtProperty);
        booking.CheckIn();

        Action action = () => booking.Cancel("Invalid cancellation", DateTime.UtcNow);

        action.Should().Throw<DomainException>()
            .Where(exception => exception.Code == "Booking.InvalidStatusForCancellation");
    }

    [Fact]
    public void MarkNoShowRequiresConfirmedBookingAndRecordsEvidence()
    {
        Booking confirmedBooking = CreateBooking(PaymentMode.PayAtProperty);
        DateTime noShowAtUtc = new(2026, 7, 19, 12, 0, 0, DateTimeKind.Utc);

        confirmedBooking.MarkNoShow("Guest missed arrival window", noShowAtUtc);

        confirmedBooking.Status.Should().Be(BookingStatus.NoShow);
        confirmedBooking.NoShowReason.Should().Be("Guest missed arrival window");
        confirmedBooking.NoShowAtUtc.Should().Be(noShowAtUtc);

        Booking pendingBooking = CreateBooking(PaymentMode.PlatformCollect);
        Action action = () => pendingBooking.MarkNoShow("Not confirmed", noShowAtUtc);
        action.Should().Throw<DomainException>()
            .Where(exception => exception.Code == "Booking.InvalidStatusForNoShow");
    }

    [Fact]
    public void ReleaseAssignmentRequiresAssignedRoom()
    {
        PhysicalRoom room = new(Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), "101");
        room.AssignForStay();

        room.ReleaseAssignment();

        room.Status.Should().Be(RoomOperationalStatus.Available);
        Action repeatedRelease = room.ReleaseAssignment;
        repeatedRelease.Should().Throw<DomainException>()
            .Where(exception => exception.Code == "PhysicalRoom.InvalidAssignmentReleaseStatus");
    }

    private static Booking CreateBooking(PaymentMode paymentMode)
    {
        Booking booking = new(
            Guid.NewGuid(),
            $"BK{Guid.NewGuid():N}"[..32],
            Guid.NewGuid(),
            Guid.NewGuid(),
            new DateOnly(2026, 8, 1),
            new DateOnly(2026, 8, 3),
            paymentMode,
            BookingSource.Marketplace,
            200m,
            "Test Guest",
            "0900000000");

        if (paymentMode == PaymentMode.PlatformCollect)
        {
            booking.SetPaymentExpiration(DateTime.UtcNow.AddMinutes(15));
        }

        return booking;
    }
}
