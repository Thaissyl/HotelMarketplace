using FluentAssertions;
using HotelMarketplace.Domain.Entities;
using HotelMarketplace.SharedKernel.Exceptions;
using Xunit;

namespace HotelMarketplace.Domain.UnitTests;

public sealed class StaffLifecycleTests
{
    [Fact]
    public void RevokedAssignmentCanBeReactivatedWithAHotelRole()
    {
        HotelStaffAssignment assignment = CreateAssignment();
        Guid replacementRoleId = Guid.NewGuid();

        assignment.Revoke();
        assignment.Reactivate(replacementRoleId);

        assignment.IsActive.Should().BeTrue();
        assignment.RoleId.Should().Be(replacementRoleId);
    }

    [Fact]
    public void InactiveAssignmentCannotChangeRoleWithoutReactivation()
    {
        HotelStaffAssignment assignment = CreateAssignment();
        assignment.Revoke();

        Action action = () => assignment.ChangeRole(Guid.NewGuid());

        action.Should().Throw<DomainException>()
            .Where(exception => exception.Code == "HotelStaffAssignment.InactiveRoleChange");
    }

    [Fact]
    public void AccountRoleCanBeRevokedAndReactivatedIdempotently()
    {
        UserAccountRole accountRole = new(Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid());

        accountRole.Revoke();
        accountRole.Revoke();
        accountRole.IsActive.Should().BeFalse();

        accountRole.Reactivate();
        accountRole.Reactivate();
        accountRole.IsActive.Should().BeTrue();
    }

    private static HotelStaffAssignment CreateAssignment()
    {
        return new HotelStaffAssignment(
            Guid.NewGuid(),
            Guid.NewGuid(),
            Guid.NewGuid(),
            Guid.NewGuid(),
            Guid.NewGuid());
    }
}
