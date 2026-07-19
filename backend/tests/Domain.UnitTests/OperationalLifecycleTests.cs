using FluentAssertions;
using HotelMarketplace.Domain.Entities;
using HotelMarketplace.Domain.Enums;
using HotelMarketplace.SharedKernel.Exceptions;
using Xunit;

namespace HotelMarketplace.Domain.UnitTests;

public sealed class OperationalLifecycleTests
{
    [Fact]
    public void CleaningRequiresInspectionBeforeRoomBecomesAvailable()
    {
        PhysicalRoom room = new(Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), "201");
        room.MarkOccupiedForCheckIn();
        room.ReleaseToHousekeeping();
        HousekeepingTask task = new(Guid.NewGuid(), room.HotelId, room.Id, "CheckoutCleaning");
        Guid housekeeperId = Guid.NewGuid();

        task.Start(housekeeperId);
        room.StartHousekeeping();
        task.CompleteCleaning(requiresInspection: true);
        room.CompleteHousekeeping(requiresInspection: true);

        task.Status.Should().Be(HousekeepingTaskStatus.InspectionRequired);
        room.Status.Should().Be(RoomOperationalStatus.InspectionRequired);

        task.CompleteInspection();
        room.CompleteInspection();

        task.Status.Should().Be(HousekeepingTaskStatus.Completed);
        room.Status.Should().Be(RoomOperationalStatus.Available);
    }

    [Fact]
    public void MaintenanceResolutionDoesNotReleaseRoomDirectly()
    {
        PhysicalRoom room = new(Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), "202");
        MaintenanceRequest request = new(
            Guid.NewGuid(),
            room.HotelId,
            room.Id,
            Guid.NewGuid(),
            "Air conditioning failure",
            MaintenanceSeverity.High);
        Guid technicianId = Guid.NewGuid();

        room.BlockForMaintenance(RoomOperationalStatus.Maintenance);
        request.Start(technicianId);
        request.Resolve("Replaced the failed compressor.", new DateTime(2026, 7, 19, 12, 0, 0, DateTimeKind.Utc));
        room.CompleteMaintenance(requiresInspection: true);

        request.Status.Should().Be(MaintenanceStatus.Resolved);
        room.Status.Should().Be(RoomOperationalStatus.InspectionRequired);

        request.Release();
        room.CompleteInspection();
        request.Status.Should().Be(MaintenanceStatus.Released);
        room.Status.Should().Be(RoomOperationalStatus.Available);
    }

    [Fact]
    public void SetupCannotOverrideOperationalStatus()
    {
        PhysicalRoom room = new(Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), "203");
        room.MarkOccupiedForCheckIn();
        room.ReleaseToHousekeeping();

        Action action = () => room.ChangeSetupStatus(RoomOperationalStatus.Available);

        action.Should().Throw<DomainException>()
            .Where(exception => exception.Code == "PhysicalRoom.OperationalStatusCannotBeOverridden");
    }
}
