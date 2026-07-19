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

        task.Start(housekeeperId, canOverrideAssignee: false);
        room.StartHousekeeping();
        task.CompleteCleaning(housekeeperId, canOverrideAssignee: false, requiresInspection: true);
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
        request.Start(technicianId, canOverrideAssignee: false);
        request.Resolve(
            technicianId,
            canOverrideAssignee: false,
            "Replaced the failed compressor.",
            new DateTime(2026, 7, 19, 12, 0, 0, DateTimeKind.Utc));
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

    [Fact]
    public void HousekeeperCannotTakeOverAnotherAssigneesTask()
    {
        Guid assignedHousekeeperId = Guid.NewGuid();
        HousekeepingTask task = new(
            Guid.NewGuid(),
            Guid.NewGuid(),
            Guid.NewGuid(),
            "CheckoutCleaning",
            assignedToUserAccountId: assignedHousekeeperId);

        Action action = () => task.Start(Guid.NewGuid(), canOverrideAssignee: false);

        action.Should().Throw<DomainException>()
            .Where(exception => exception.Code == "HousekeepingTask.AssigneeOwnershipConflict");
        task.Status.Should().Be(HousekeepingTaskStatus.Open);
        task.AssignedToUserAccountId.Should().Be(assignedHousekeeperId);
    }

    [Fact]
    public void ManagerCanProgressAnotherHousekeepersTaskWithoutChangingAssignee()
    {
        Guid assignedHousekeeperId = Guid.NewGuid();
        HousekeepingTask task = new(
            Guid.NewGuid(),
            Guid.NewGuid(),
            Guid.NewGuid(),
            "CheckoutCleaning",
            assignedToUserAccountId: assignedHousekeeperId);

        task.Start(Guid.NewGuid(), canOverrideAssignee: true);

        task.Status.Should().Be(HousekeepingTaskStatus.InProgress);
        task.AssignedToUserAccountId.Should().Be(assignedHousekeeperId);
    }

    [Fact]
    public void TechnicianCannotResolveAnotherAssigneesRequest()
    {
        Guid assignedTechnicianId = Guid.NewGuid();
        MaintenanceRequest request = new(
            Guid.NewGuid(),
            Guid.NewGuid(),
            Guid.NewGuid(),
            Guid.NewGuid(),
            "Electrical fault",
            MaintenanceSeverity.High);
        request.Assign(assignedTechnicianId);
        request.Start(assignedTechnicianId, canOverrideAssignee: false);

        Action action = () => request.Resolve(
            Guid.NewGuid(),
            canOverrideAssignee: false,
            "Repaired wiring.",
            new DateTime(2026, 7, 19, 12, 0, 0, DateTimeKind.Utc));

        action.Should().Throw<DomainException>()
            .Where(exception => exception.Code == "MaintenanceRequest.AssigneeOwnershipConflict");
        request.Status.Should().Be(MaintenanceStatus.InProgress);
    }
}
