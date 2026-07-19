using FluentAssertions;
using HotelMarketplace.Domain.Entities;
using HotelMarketplace.Domain.Enums;
using HotelMarketplace.SharedKernel.Exceptions;
using Xunit;

namespace HotelMarketplace.Domain.UnitTests;

public sealed class ContractCompletenessTests
{
    [Fact]
    public void BookingRequiresPositiveGuestCount()
    {
        Func<Booking> create = () => new Booking(
            Guid.NewGuid(),
            $"BK{Guid.NewGuid():N}"[..32],
            Guid.NewGuid(),
            Guid.NewGuid(),
            new DateOnly(2026, 9, 1),
            new DateOnly(2026, 9, 3),
            PaymentMode.PayAtProperty,
            BookingSource.Marketplace,
            200m,
            0,
            "Contract Guest",
            "0900000000");

        create.Should().Throw<DomainException>();
    }

    [Fact]
    public void RoomAndHotelContentPreserveValidatedOperationalDetails()
    {
        Guid hotelId = Guid.NewGuid();
        RoomType roomType = new(
            Guid.NewGuid(),
            hotelId,
            "Family Residence",
            2,
            2,
            175m,
            "Private residence.",
            "Wi-Fi, workspace, minibar");
        PhysicalRoom room = new(
            Guid.NewGuid(),
            hotelId,
            roomType.Id,
            "1204",
            RoomOperationalStatus.Available,
            "12",
            "Quiet-side room");
        Amenity amenity = new(Guid.NewGuid(), "wifi", "High-speed Wi-Fi", "Connectivity");
        CancellationPolicy policy = new(
            Guid.NewGuid(),
            hotelId,
            "Flexible 48 hours",
            48,
            80m,
            "Cancel early for a partial refund.");

        roomType.Facilities.Should().Contain("workspace");
        room.Floor.Should().Be("12");
        room.Notes.Should().Be("Quiet-side room");
        amenity.Code.Should().Be("WIFI");
        amenity.Status.Should().Be(RecordStatus.Active);
        policy.Description.Should().Contain("partial refund");
        policy.Status.Should().Be(RecordStatus.Active);
    }
}
