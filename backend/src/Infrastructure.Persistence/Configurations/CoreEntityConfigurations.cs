using HotelMarketplace.Domain.Entities;
using HotelMarketplace.Domain.Enums;
using HotelMarketplace.Domain.Security;
using HotelMarketplace.Infrastructure.Persistence.Configurations;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace HotelMarketplace.Infrastructure.Persistence.Configurations;

internal sealed class UserAccountConfiguration : IEntityTypeConfiguration<UserAccount>
{
    public void Configure(EntityTypeBuilder<UserAccount> builder)
    {
        builder.ConfigureEntity("UserAccounts");
        builder.Property(entity => entity.Email).HasMaxLength(256).IsRequired();
        builder.Property(entity => entity.PhoneNumber).HasMaxLength(32);
        builder.Property(entity => entity.PasswordHash).HasMaxLength(512).IsRequired();
        builder.Property(entity => entity.FullName).HasMaxLength(200).IsRequired();
        builder.Property(entity => entity.Status).HasEnumConversion();
        builder.Property(entity => entity.IsSystemAccount).IsRequired();
        builder.Property(entity => entity.CreatedAtUtc).HasPrecision(3);
        builder.HasIndex(entity => entity.Email).IsUnique();
        builder.HasIndex(entity => entity.PhoneNumber).IsUnique().HasFilter("[PhoneNumber] IS NOT NULL");

        builder.HasData(new
        {
            Id = SeededUserAccountIds.AnonymousWalkInCustomer,
            Email = "anonymous-walk-in@system.local",
            PhoneNumber = (string?)null,
            PasswordHash = "LOGIN-DISABLED",
            FullName = "Anonymous Walk-in Customer",
            Status = AccountStatus.Active,
            IsSystemAccount = true,
            CreatedAtUtc = new DateTime(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc)
        });
    }
}

internal sealed class UserRoleConfiguration : IEntityTypeConfiguration<UserRole>
{
    public void Configure(EntityTypeBuilder<UserRole> builder)
    {
        builder.ConfigureEntity("UserRoles");
        builder.Property(entity => entity.Code).HasMaxLength(64).IsRequired();
        builder.Property(entity => entity.Name).HasMaxLength(128).IsRequired();
        builder.Property(entity => entity.Scope).HasEnumConversion();
        builder.HasIndex(entity => entity.Code).IsUnique();

        builder.HasData(
            new UserRole(SeededRoleIds.Customer, UserRoleCode.Customer.ToString(), "Customer", RoleScope.Customer),
            new UserRole(SeededRoleIds.PropertyOwner, UserRoleCode.PropertyOwner.ToString(), "Property Owner", RoleScope.Hotel),
            new UserRole(SeededRoleIds.HotelManager, UserRoleCode.HotelManager.ToString(), "Hotel Manager", RoleScope.Hotel),
            new UserRole(SeededRoleIds.Receptionist, UserRoleCode.Receptionist.ToString(), "Receptionist", RoleScope.Hotel),
            new UserRole(SeededRoleIds.HousekeepingStaff, UserRoleCode.HousekeepingStaff.ToString(), "Housekeeping Staff", RoleScope.Hotel),
            new UserRole(SeededRoleIds.MaintenanceStaff, UserRoleCode.MaintenanceStaff.ToString(), "Maintenance Staff", RoleScope.Hotel),
            new UserRole(SeededRoleIds.PlatformAdministrator, UserRoleCode.PlatformAdministrator.ToString(), "Platform Administrator", RoleScope.Platform));
    }
}

internal sealed class UserAccountRoleConfiguration : IEntityTypeConfiguration<UserAccountRole>
{
    public void Configure(EntityTypeBuilder<UserAccountRole> builder)
    {
        builder.ConfigureEntity("UserAccountRoles");
        builder.Property(entity => entity.AssignedAtUtc).HasPrecision(3);
        builder.HasIndex(entity => new { entity.UserAccountId, entity.RoleId }).IsUnique().HasFilter("[IsActive] = 1");
        builder.HasOne<UserAccount>().WithMany("Roles").HasForeignKey(entity => entity.UserAccountId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<UserRole>().WithMany().HasForeignKey(entity => entity.RoleId).OnDelete(DeleteBehavior.Restrict);

        builder.HasData(new
        {
            Id = SeededUserAccountIds.AnonymousWalkInCustomerRole,
            UserAccountId = SeededUserAccountIds.AnonymousWalkInCustomer,
            RoleId = SeededRoleIds.Customer,
            IsActive = true,
            AssignedAtUtc = new DateTime(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc)
        });
    }
}

internal sealed class HotelPropertyConfiguration : IEntityTypeConfiguration<HotelProperty>
{
    public void Configure(EntityTypeBuilder<HotelProperty> builder)
    {
        builder.ConfigureEntity("HotelProperties");
        builder.Property(entity => entity.OwnerUserAccountId).IsRequired();
        builder.Property(entity => entity.Name).HasMaxLength(200).IsRequired();
        builder.Property(entity => entity.City).HasMaxLength(100).IsRequired();
        builder.Property(entity => entity.AddressLine).HasMaxLength(300).IsRequired();
        builder.Property(entity => entity.ContactEmail).HasMaxLength(256).IsRequired();
        builder.Property(entity => entity.ContactPhone).HasMaxLength(32).IsRequired();
        builder.Property(entity => entity.Description).HasMaxLength(2000);
        builder.Property(entity => entity.ApprovalStatus).HasEnumConversion();
        builder.Property(entity => entity.PublicationStatus).HasEnumConversion();
        builder.Property(entity => entity.DefaultCommissionRate).HasPrecision(5, 4);
        builder.Property(entity => entity.CreatedAtUtc).HasPrecision(3);
        builder.HasIndex(entity => new { entity.City, entity.ApprovalStatus, entity.PublicationStatus });
        builder.HasOne<UserAccount>().WithMany().HasForeignKey(entity => entity.OwnerUserAccountId).OnDelete(DeleteBehavior.Restrict);
        builder.ToTable(table => table.HasCheckConstraint("CK_HotelProperties_DefaultCommissionRate", "[DefaultCommissionRate] >= 0 AND [DefaultCommissionRate] <= 0.30"));
    }
}

internal sealed class HotelImageConfiguration : IEntityTypeConfiguration<HotelImage>
{
    public void Configure(EntityTypeBuilder<HotelImage> builder)
    {
        builder.ConfigureEntity("HotelImages");
        builder.Property(entity => entity.ImageUrl).HasMaxLength(1000).IsRequired();
        builder.Property(entity => entity.Status).HasEnumConversion();
        builder.HasIndex(entity => new { entity.HotelId, entity.DisplayOrder });
        builder.HasOne<HotelProperty>().WithMany("Images").HasForeignKey(entity => entity.HotelId).OnDelete(DeleteBehavior.Cascade);
    }
}

internal sealed class AmenityConfiguration : IEntityTypeConfiguration<Amenity>
{
    public void Configure(EntityTypeBuilder<Amenity> builder)
    {
        builder.ConfigureEntity("Amenities");
        builder.Property(entity => entity.Code).HasMaxLength(64).IsRequired();
        builder.Property(entity => entity.Name).HasMaxLength(128).IsRequired();
        builder.HasIndex(entity => entity.Code).IsUnique();
    }
}

internal sealed class HotelAmenityConfiguration : IEntityTypeConfiguration<HotelAmenity>
{
    public void Configure(EntityTypeBuilder<HotelAmenity> builder)
    {
        builder.ConfigureEntity("HotelAmenities");
        builder.HasIndex(entity => new { entity.HotelId, entity.AmenityId }).IsUnique();
        builder.HasOne<HotelProperty>().WithMany("Amenities").HasForeignKey(entity => entity.HotelId).OnDelete(DeleteBehavior.Cascade);
        builder.HasOne<Amenity>().WithMany().HasForeignKey(entity => entity.AmenityId).OnDelete(DeleteBehavior.Restrict);
    }
}

internal sealed class CancellationPolicyConfiguration : IEntityTypeConfiguration<CancellationPolicy>
{
    public void Configure(EntityTypeBuilder<CancellationPolicy> builder)
    {
        builder.ConfigureEntity("CancellationPolicies");
        builder.Property(entity => entity.Name).HasMaxLength(128).IsRequired();
        builder.Property(entity => entity.RefundPercentage).HasPrecision(5, 2);
        builder.HasIndex(entity => entity.HotelId).IsUnique();
        builder.HasOne<HotelProperty>().WithMany().HasForeignKey(entity => entity.HotelId).OnDelete(DeleteBehavior.Cascade);
        builder.ToTable(table =>
        {
            table.HasCheckConstraint("CK_CancellationPolicies_FreeCancellationHours", "[FreeCancellationHours] >= 0");
            table.HasCheckConstraint("CK_CancellationPolicies_RefundPercentage", "[RefundPercentage] >= 0 AND [RefundPercentage] <= 100");
        });
    }
}

internal sealed class HotelStaffAssignmentConfiguration : IEntityTypeConfiguration<HotelStaffAssignment>
{
    public void Configure(EntityTypeBuilder<HotelStaffAssignment> builder)
    {
        builder.ConfigureEntity("HotelStaffAssignments");
        builder.Property(entity => entity.AssignedAtUtc).HasPrecision(3);
        builder.HasIndex(entity => new { entity.UserAccountId, entity.HotelId, entity.RoleId }).IsUnique().HasFilter("[IsActive] = 1");
        builder.HasOne<UserAccount>().WithMany("StaffAssignments").HasForeignKey(entity => entity.UserAccountId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<HotelProperty>().WithMany().HasForeignKey(entity => entity.HotelId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<UserRole>().WithMany().HasForeignKey(entity => entity.RoleId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<UserAccount>().WithMany().HasForeignKey(entity => entity.AssignedByUserAccountId).OnDelete(DeleteBehavior.Restrict);
    }
}

internal sealed class StaffInvitationConfiguration : IEntityTypeConfiguration<StaffInvitation>
{
    public void Configure(EntityTypeBuilder<StaffInvitation> builder)
    {
        builder.ConfigureEntity("StaffInvitations");
        builder.Property(entity => entity.Email).HasMaxLength(256).IsRequired();
        builder.Property(entity => entity.Status).HasEnumConversion();
        builder.Property(entity => entity.InvitedAtUtc).HasPrecision(3);
        builder.Property(entity => entity.ExpiresAtUtc).HasPrecision(3);
        builder.HasIndex(entity => new { entity.HotelId, entity.Email, entity.RoleId }).HasFilter("[Status] = 'Active'");
        builder.HasOne<HotelProperty>().WithMany().HasForeignKey(entity => entity.HotelId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<UserRole>().WithMany().HasForeignKey(entity => entity.RoleId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<UserAccount>().WithMany().HasForeignKey(entity => entity.InvitedByUserAccountId).OnDelete(DeleteBehavior.Restrict);
    }
}

internal sealed class RoomTypeConfiguration : IEntityTypeConfiguration<RoomType>
{
    public void Configure(EntityTypeBuilder<RoomType> builder)
    {
        builder.ConfigureEntity("RoomTypes");
        builder.Property(entity => entity.Name).HasMaxLength(160).IsRequired();
        builder.Property(entity => entity.BasePricePerNight).HasPrecision(18, 2);
        builder.Property(entity => entity.Description).HasMaxLength(1000);
        builder.Property(entity => entity.Status).HasEnumConversion();
        builder.HasIndex(entity => new { entity.HotelId, entity.Status });
        builder.HasOne<HotelProperty>().WithMany("RoomTypes").HasForeignKey(entity => entity.HotelId).OnDelete(DeleteBehavior.Restrict);
        builder.ToTable(table =>
        {
            table.HasCheckConstraint("CK_RoomTypes_AdultCapacity", "[AdultCapacity] > 0");
            table.HasCheckConstraint("CK_RoomTypes_ChildCapacity", "[ChildCapacity] >= 0");
            table.HasCheckConstraint("CK_RoomTypes_BasePricePerNight", "[BasePricePerNight] >= 0");
        });
    }
}

internal sealed class PhysicalRoomConfiguration : IEntityTypeConfiguration<PhysicalRoom>
{
    public void Configure(EntityTypeBuilder<PhysicalRoom> builder)
    {
        builder.ConfigureEntity("PhysicalRooms");
        builder.Property(entity => entity.RoomNumber).HasMaxLength(32).IsRequired();
        builder.Property(entity => entity.Status).HasEnumConversion();
        builder.HasIndex(entity => new { entity.HotelId, entity.RoomNumber }).IsUnique();
        builder.HasIndex(entity => new { entity.HotelId, entity.RoomTypeId, entity.Status });
        builder.HasOne<HotelProperty>().WithMany("PhysicalRooms").HasForeignKey(entity => entity.HotelId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<RoomType>().WithMany().HasForeignKey(entity => entity.RoomTypeId).OnDelete(DeleteBehavior.Restrict);
    }
}

internal sealed class RoomAvailabilityConfiguration : IEntityTypeConfiguration<RoomAvailability>
{
    public void Configure(EntityTypeBuilder<RoomAvailability> builder)
    {
        builder.ConfigureEntity("RoomAvailabilities");
        builder.Property(entity => entity.StartDate).HasColumnType("date");
        builder.Property(entity => entity.EndDate).HasColumnType("date");
        builder.Property(entity => entity.Status).HasEnumConversion();
        builder.HasIndex(entity => new { entity.HotelId, entity.RoomTypeId, entity.StartDate, entity.EndDate, entity.Status });
        builder.HasOne<HotelProperty>().WithMany().HasForeignKey(entity => entity.HotelId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<RoomType>().WithMany().HasForeignKey(entity => entity.RoomTypeId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<PhysicalRoom>().WithMany().HasForeignKey(entity => entity.PhysicalRoomId).OnDelete(DeleteBehavior.Restrict);
        builder.ToTable(table => table.HasCheckConstraint("CK_RoomAvailabilities_DateRange", "[EndDate] > [StartDate]"));
    }
}
