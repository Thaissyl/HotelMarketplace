using HotelMarketplace.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace HotelMarketplace.Infrastructure.Persistence.Configurations;

internal sealed class NotificationRecordConfiguration : IEntityTypeConfiguration<NotificationRecord>
{
    public void Configure(EntityTypeBuilder<NotificationRecord> builder)
    {
        builder.ConfigureEntity("NotificationRecords");
        builder.Property(entity => entity.EventType).HasMaxLength(128).IsRequired();
        builder.Property(entity => entity.RelatedEntityType).HasMaxLength(128).IsRequired();
        builder.Property(entity => entity.Message).HasMaxLength(1000).IsRequired();
        builder.Property(entity => entity.Status).HasEnumConversion();
        builder.Property(entity => entity.CreatedAtUtc).HasPrecision(3);
        builder.Property(entity => entity.ReadAtUtc).HasPrecision(3);
        builder.HasIndex(entity => new { entity.RelatedEntityType, entity.RelatedEntityId });
        builder.HasIndex(entity => new { entity.HotelId, entity.Status });
        builder.HasIndex(entity => new { entity.RecipientUserAccountId, entity.ReadAtUtc, entity.CreatedAtUtc });
        builder.HasOne<HotelProperty>().WithMany().HasForeignKey(entity => entity.HotelId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<UserAccount>().WithMany().HasForeignKey(entity => entity.RecipientUserAccountId).OnDelete(DeleteBehavior.Restrict);
    }
}

internal sealed class SavedHotelConfiguration : IEntityTypeConfiguration<SavedHotel>
{
    public void Configure(EntityTypeBuilder<SavedHotel> builder)
    {
        builder.ConfigureEntity("SavedHotels");
        builder.Property(entity => entity.CreatedAtUtc).HasPrecision(3);
        builder.HasIndex(entity => new { entity.UserAccountId, entity.HotelId }).IsUnique();
        builder.HasIndex(entity => new { entity.UserAccountId, entity.CreatedAtUtc });
        builder.HasOne<UserAccount>().WithMany().HasForeignKey(entity => entity.UserAccountId).OnDelete(DeleteBehavior.Cascade);
        builder.HasOne<HotelProperty>().WithMany().HasForeignKey(entity => entity.HotelId).OnDelete(DeleteBehavior.Cascade);
    }
}

internal sealed class AuditRecordConfiguration : IEntityTypeConfiguration<AuditRecord>
{
    public void Configure(EntityTypeBuilder<AuditRecord> builder)
    {
        builder.ConfigureEntity("AuditRecords");
        builder.Property(entity => entity.ActionType).HasMaxLength(128).IsRequired();
        builder.Property(entity => entity.TargetEntityType).HasMaxLength(128).IsRequired();
        builder.Property(entity => entity.Summary).HasMaxLength(1000).IsRequired();
        builder.Property(entity => entity.ActionTimestampUtc).HasPrecision(3);
        builder.HasIndex(entity => new { entity.TargetEntityType, entity.TargetEntityId, entity.ActionTimestampUtc });
        builder.HasIndex(entity => new { entity.HotelId, entity.ActionTimestampUtc });
        builder.HasOne<HotelProperty>().WithMany().HasForeignKey(entity => entity.HotelId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<UserAccount>().WithMany().HasForeignKey(entity => entity.ActorUserAccountId).OnDelete(DeleteBehavior.Restrict).IsRequired(false);
    }
}

internal sealed class HousekeepingTaskConfiguration : IEntityTypeConfiguration<HousekeepingTask>
{
    public void Configure(EntityTypeBuilder<HousekeepingTask> builder)
    {
        builder.ConfigureEntity("HousekeepingTasks");
        builder.Property(entity => entity.TaskType).HasMaxLength(64).IsRequired();
        builder.Property(entity => entity.Status).HasEnumConversion();
        builder.Property(entity => entity.CreatedAtUtc).HasPrecision(3);
        builder.HasIndex(entity => new { entity.HotelId, entity.Status, entity.AssignedToUserAccountId });
        builder.HasIndex(entity => entity.PhysicalRoomId);
        builder.HasOne<HotelProperty>().WithMany().HasForeignKey(entity => entity.HotelId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<PhysicalRoom>().WithMany().HasForeignKey(entity => entity.PhysicalRoomId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<Booking>().WithMany().HasForeignKey(entity => entity.BookingId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<UserAccount>().WithMany().HasForeignKey(entity => entity.AssignedToUserAccountId).OnDelete(DeleteBehavior.Restrict);
    }
}

internal sealed class MaintenanceRequestConfiguration : IEntityTypeConfiguration<MaintenanceRequest>
{
    public void Configure(EntityTypeBuilder<MaintenanceRequest> builder)
    {
        builder.ConfigureEntity("MaintenanceRequests");
        builder.Property(entity => entity.Description).HasMaxLength(1000).IsRequired();
        builder.Property(entity => entity.Severity).HasEnumConversion();
        builder.Property(entity => entity.Status).HasEnumConversion();
        builder.Property(entity => entity.CreatedAtUtc).HasPrecision(3);
        builder.Property(entity => entity.ResolvedAtUtc).HasPrecision(3);
        builder.Property(entity => entity.ResolutionNote).HasMaxLength(1000);
        builder.HasIndex(entity => new { entity.HotelId, entity.Status, entity.AssignedToUserAccountId });
        builder.HasIndex(entity => entity.PhysicalRoomId);
        builder.HasOne<HotelProperty>().WithMany().HasForeignKey(entity => entity.HotelId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<PhysicalRoom>().WithMany().HasForeignKey(entity => entity.PhysicalRoomId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<UserAccount>().WithMany().HasForeignKey(entity => entity.ReportedByUserAccountId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<UserAccount>().WithMany().HasForeignKey(entity => entity.AssignedToUserAccountId).OnDelete(DeleteBehavior.Restrict);
    }
}

internal sealed class RoomStatusHistoryConfiguration : IEntityTypeConfiguration<RoomStatusHistory>
{
    public void Configure(EntityTypeBuilder<RoomStatusHistory> builder)
    {
        builder.ConfigureEntity("RoomStatusHistories");
        builder.Property(entity => entity.OldStatus).HasEnumConversion();
        builder.Property(entity => entity.NewStatus).HasEnumConversion();
        builder.Property(entity => entity.ChangedAtUtc).HasPrecision(3);
        builder.HasIndex(entity => new { entity.PhysicalRoomId, entity.ChangedAtUtc });
        builder.HasOne<HotelProperty>().WithMany().HasForeignKey(entity => entity.HotelId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<PhysicalRoom>().WithMany().HasForeignKey(entity => entity.PhysicalRoomId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<UserAccount>().WithMany().HasForeignKey(entity => entity.ChangedByUserAccountId).OnDelete(DeleteBehavior.Restrict);
    }
}

internal sealed class GuestStayRecordConfiguration : IEntityTypeConfiguration<GuestStayRecord>
{
    public void Configure(EntityTypeBuilder<GuestStayRecord> builder)
    {
        builder.ConfigureEntity("GuestStayRecords");
        builder.Property(entity => entity.GuestFullName).HasMaxLength(200).IsRequired();
        builder.Property(entity => entity.IdentityDocumentType).HasMaxLength(32).IsRequired();
        builder.Property(entity => entity.IdentityDocumentNumber).HasMaxLength(64).IsRequired();
        builder.Property(entity => entity.IdentityIssuingCountry).HasMaxLength(2);
        builder.Property(entity => entity.CheckedInAtUtc).HasPrecision(3);
        builder.Property(entity => entity.CheckedOutAtUtc).HasPrecision(3);
        builder.HasIndex(entity => entity.BookingId).IsUnique();
        builder.HasIndex(entity => new { entity.HotelId, entity.CheckedInAtUtc });
        builder.HasOne<HotelProperty>().WithMany().HasForeignKey(entity => entity.HotelId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<Booking>().WithMany().HasForeignKey(entity => entity.BookingId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<UserAccount>().WithMany().HasForeignKey(entity => entity.CheckedInByUserAccountId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<UserAccount>().WithMany().HasForeignKey(entity => entity.CheckedOutByUserAccountId).OnDelete(DeleteBehavior.Restrict);
    }
}
