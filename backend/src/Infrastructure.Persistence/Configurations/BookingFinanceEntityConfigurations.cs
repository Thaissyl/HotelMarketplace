using HotelMarketplace.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace HotelMarketplace.Infrastructure.Persistence.Configurations;

internal sealed class BookingConfiguration : IEntityTypeConfiguration<Booking>
{
    public void Configure(EntityTypeBuilder<Booking> builder)
    {
        builder.ConfigureEntity("Bookings");
        builder.Property(entity => entity.BookingCode).HasMaxLength(32).IsRequired();
        builder.Property(entity => entity.CheckInDate).HasColumnType("date");
        builder.Property(entity => entity.CheckOutDate).HasColumnType("date");
        builder.Property(entity => entity.PaymentMode).HasEnumConversion();
        builder.Property(entity => entity.Source).HasEnumConversion();
        builder.Property(entity => entity.Status).HasEnumConversion();
        builder.Property(entity => entity.TotalAmount).HasPrecision(18, 2);
        builder.Property(entity => entity.GuestFullName).HasMaxLength(200).IsRequired();
        builder.Property(entity => entity.GuestPhone).HasMaxLength(32).IsRequired();
        builder.Property(entity => entity.CreatedAtUtc).HasPrecision(3);
        builder.Property(entity => entity.PaymentExpiresAtUtc).HasPrecision(3);
        builder.HasIndex(entity => entity.BookingCode).IsUnique();
        builder.HasIndex(entity => new { entity.HotelId, entity.CheckInDate, entity.CheckOutDate, entity.Status });
        builder.HasIndex(entity => new { entity.CustomerUserAccountId, entity.CreatedAtUtc });
        builder.HasOne<UserAccount>().WithMany().HasForeignKey(entity => entity.CustomerUserAccountId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<HotelProperty>().WithMany().HasForeignKey(entity => entity.HotelId).OnDelete(DeleteBehavior.Restrict);
        builder.ToTable(table =>
        {
            table.HasCheckConstraint("CK_Bookings_StayDates", "[CheckOutDate] > [CheckInDate]");
            table.HasCheckConstraint("CK_Bookings_TotalAmount", "[TotalAmount] >= 0");
        });
    }
}

internal sealed class BookingRoomConfiguration : IEntityTypeConfiguration<BookingRoom>
{
    public void Configure(EntityTypeBuilder<BookingRoom> builder)
    {
        builder.ConfigureEntity("BookingRooms");
        builder.Property(entity => entity.UnitPricePerNight).HasPrecision(18, 2);
        builder.Property(entity => entity.LineAmount).HasPrecision(18, 2);
        builder.HasIndex(entity => entity.BookingId).IsUnique();
        builder.HasOne<Booking>().WithMany("Rooms").HasForeignKey(entity => entity.BookingId).OnDelete(DeleteBehavior.Cascade);
        builder.HasOne<RoomType>().WithMany().HasForeignKey(entity => entity.RoomTypeId).OnDelete(DeleteBehavior.Restrict);
        builder.ToTable(table =>
        {
            table.HasCheckConstraint("CK_BookingRooms_Quantity", "[Quantity] > 0");
            table.HasCheckConstraint("CK_BookingRooms_Nights", "[Nights] > 0");
            table.HasCheckConstraint("CK_BookingRooms_UnitPricePerNight", "[UnitPricePerNight] >= 0");
            table.HasCheckConstraint("CK_BookingRooms_LineAmount", "[LineAmount] >= 0");
        });
    }
}

internal sealed class BookingRoomAssignmentConfiguration : IEntityTypeConfiguration<BookingRoomAssignment>
{
    public void Configure(EntityTypeBuilder<BookingRoomAssignment> builder)
    {
        builder.ConfigureEntity("BookingRoomAssignments");
        builder.Property(entity => entity.StartDate).HasColumnType("date");
        builder.Property(entity => entity.EndDate).HasColumnType("date");
        builder.Property(entity => entity.Status).HasEnumConversion();
        builder.Property(entity => entity.AssignedAtUtc).HasPrecision(3);
        builder.HasIndex(entity => new { entity.PhysicalRoomId, entity.StartDate, entity.EndDate, entity.Status });
        builder.HasIndex(entity => new { entity.HotelId, entity.BookingId });
        builder.HasOne<HotelProperty>().WithMany().HasForeignKey(entity => entity.HotelId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<Booking>().WithMany().HasForeignKey(entity => entity.BookingId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<BookingRoom>().WithMany().HasForeignKey(entity => entity.BookingRoomId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<PhysicalRoom>().WithMany().HasForeignKey(entity => entity.PhysicalRoomId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<UserAccount>().WithMany().HasForeignKey(entity => entity.AssignedByUserAccountId).OnDelete(DeleteBehavior.Restrict);
        builder.ToTable(table => table.HasCheckConstraint("CK_BookingRoomAssignments_DateRange", "[EndDate] > [StartDate]"));
    }
}

internal sealed class PaymentTransactionConfiguration : IEntityTypeConfiguration<PaymentTransaction>
{
    public void Configure(EntityTypeBuilder<PaymentTransaction> builder)
    {
        builder.ConfigureEntity("PaymentTransactions");
        builder.Property(entity => entity.Provider).HasMaxLength(64).IsRequired();
        builder.Property(entity => entity.GatewayReference).HasMaxLength(128);
        builder.Property(entity => entity.Amount).HasPrecision(18, 2);
        builder.Property(entity => entity.Status).HasEnumConversion();
        builder.Property(entity => entity.ReconciliationStatus).HasEnumConversion();
        builder.Property(entity => entity.CreatedAtUtc).HasPrecision(3);
        builder.HasIndex(entity => entity.GatewayReference).IsUnique().HasFilter("[GatewayReference] IS NOT NULL");
        builder.HasIndex(entity => new { entity.HotelId, entity.Status, entity.ReconciliationStatus });
        builder.HasOne<HotelProperty>().WithMany().HasForeignKey(entity => entity.HotelId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<Booking>().WithMany().HasForeignKey(entity => entity.BookingId).OnDelete(DeleteBehavior.Restrict);
        builder.ToTable(table => table.HasCheckConstraint("CK_PaymentTransactions_Amount", "[Amount] >= 0"));
    }
}

internal sealed class PaymentCollectionRecordConfiguration : IEntityTypeConfiguration<PaymentCollectionRecord>
{
    public void Configure(EntityTypeBuilder<PaymentCollectionRecord> builder)
    {
        builder.ConfigureEntity("PaymentCollectionRecords");
        builder.Property(entity => entity.Amount).HasPrecision(18, 2);
        builder.Property(entity => entity.Status).HasEnumConversion();
        builder.Property(entity => entity.CollectedAtUtc).HasPrecision(3);
        builder.HasIndex(entity => new { entity.BookingId, entity.Status });
        builder.HasOne<HotelProperty>().WithMany().HasForeignKey(entity => entity.HotelId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<Booking>().WithMany().HasForeignKey(entity => entity.BookingId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<UserAccount>().WithMany().HasForeignKey(entity => entity.CollectedByUserAccountId).OnDelete(DeleteBehavior.Restrict);
        builder.ToTable(table => table.HasCheckConstraint("CK_PaymentCollectionRecords_Amount", "[Amount] >= 0"));
    }
}

internal sealed class RefundRecordConfiguration : IEntityTypeConfiguration<RefundRecord>
{
    public void Configure(EntityTypeBuilder<RefundRecord> builder)
    {
        builder.ConfigureEntity("RefundRecords");
        builder.Property(entity => entity.RequestedAmount).HasPrecision(18, 2);
        builder.Property(entity => entity.ApprovedAmount).HasPrecision(18, 2);
        builder.Property(entity => entity.Reason).HasMaxLength(500).IsRequired();
        builder.Property(entity => entity.Status).HasEnumConversion();
        builder.Property(entity => entity.CreatedAtUtc).HasPrecision(3);
        builder.HasIndex(entity => new { entity.HotelId, entity.Status });
        builder.HasOne<HotelProperty>().WithMany().HasForeignKey(entity => entity.HotelId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<Booking>().WithMany().HasForeignKey(entity => entity.BookingId).OnDelete(DeleteBehavior.Restrict);
        builder.ToTable(table =>
        {
            table.HasCheckConstraint("CK_RefundRecords_RequestedAmount", "[RequestedAmount] >= 0");
            table.HasCheckConstraint("CK_RefundRecords_ApprovedAmount", "[ApprovedAmount] >= 0 AND [ApprovedAmount] <= [RequestedAmount]");
        });
    }
}

internal sealed class InvoiceConfiguration : IEntityTypeConfiguration<Invoice>
{
    public void Configure(EntityTypeBuilder<Invoice> builder)
    {
        builder.ConfigureEntity("Invoices");
        builder.Property(entity => entity.InvoiceNumber).HasMaxLength(32).IsRequired();
        builder.Property(entity => entity.RoomAmount).HasPrecision(18, 2);
        builder.Property(entity => entity.PaidAmount).HasPrecision(18, 2);
        builder.Property(entity => entity.Status).HasEnumConversion();
        builder.Property(entity => entity.IssuedAtUtc).HasPrecision(3);
        builder.HasIndex(entity => entity.InvoiceNumber).IsUnique();
        builder.HasIndex(entity => entity.BookingId).IsUnique();
        builder.HasOne<HotelProperty>().WithMany().HasForeignKey(entity => entity.HotelId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<Booking>().WithMany().HasForeignKey(entity => entity.BookingId).OnDelete(DeleteBehavior.Restrict);
        builder.ToTable(table =>
        {
            table.HasCheckConstraint("CK_Invoices_RoomAmount", "[RoomAmount] >= 0");
            table.HasCheckConstraint("CK_Invoices_PaidAmount", "[PaidAmount] >= 0");
        });
    }
}

internal sealed class CommissionRecordConfiguration : IEntityTypeConfiguration<CommissionRecord>
{
    public void Configure(EntityTypeBuilder<CommissionRecord> builder)
    {
        builder.ConfigureEntity("CommissionRecords");
        builder.Property(entity => entity.BaseAmount).HasPrecision(18, 2);
        builder.Property(entity => entity.CommissionRate).HasPrecision(5, 4);
        builder.Property(entity => entity.CommissionAmount).HasPrecision(18, 2);
        builder.Property(entity => entity.CreatedAtUtc).HasPrecision(3);
        builder.HasIndex(entity => entity.BookingId).IsUnique();
        builder.HasIndex(entity => entity.HotelId);
        builder.HasOne<HotelProperty>().WithMany().HasForeignKey(entity => entity.HotelId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<Booking>().WithMany().HasForeignKey(entity => entity.BookingId).OnDelete(DeleteBehavior.Restrict);
        builder.ToTable(table =>
        {
            table.HasCheckConstraint("CK_CommissionRecords_BaseAmount", "[BaseAmount] >= 0");
            table.HasCheckConstraint("CK_CommissionRecords_CommissionRate", "[CommissionRate] >= 0 AND [CommissionRate] <= 0.30");
            table.HasCheckConstraint("CK_CommissionRecords_CommissionAmount", "[CommissionAmount] >= 0");
        });
    }
}

internal sealed class SettlementRecordConfiguration : IEntityTypeConfiguration<SettlementRecord>
{
    public void Configure(EntityTypeBuilder<SettlementRecord> builder)
    {
        builder.ConfigureEntity("SettlementRecords");
        builder.Property(entity => entity.SettlementType).HasMaxLength(64).IsRequired();
        builder.Property(entity => entity.TotalAmount).HasPrecision(18, 2);
        builder.Property(entity => entity.Status).HasEnumConversion();
        builder.Property(entity => entity.AdminNote).HasMaxLength(1000);
        builder.Property(entity => entity.CreatedAtUtc).HasPrecision(3);
        builder.HasIndex(entity => new { entity.HotelId, entity.Status });
        builder.HasOne<HotelProperty>().WithMany().HasForeignKey(entity => entity.HotelId).OnDelete(DeleteBehavior.Restrict);
        builder.ToTable(table => table.HasCheckConstraint("CK_SettlementRecords_TotalAmount", "[TotalAmount] >= 0"));
    }
}

internal sealed class SettlementItemConfiguration : IEntityTypeConfiguration<SettlementItem>
{
    public void Configure(EntityTypeBuilder<SettlementItem> builder)
    {
        builder.ConfigureEntity("SettlementItems");
        builder.Property(entity => entity.Amount).HasPrecision(18, 2);
        builder.Property(entity => entity.Status).HasEnumConversion();
        builder.HasIndex(entity => entity.SettlementRecordId);
        builder.HasOne<HotelProperty>().WithMany().HasForeignKey(entity => entity.HotelId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<SettlementRecord>().WithMany().HasForeignKey(entity => entity.SettlementRecordId).OnDelete(DeleteBehavior.Cascade);
        builder.HasOne<Booking>().WithMany().HasForeignKey(entity => entity.BookingId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<CommissionRecord>().WithMany().HasForeignKey(entity => entity.CommissionRecordId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<PaymentTransaction>().WithMany().HasForeignKey(entity => entity.PaymentTransactionId).OnDelete(DeleteBehavior.Restrict);
        builder.ToTable(table => table.HasCheckConstraint("CK_SettlementItems_Amount", "[Amount] >= 0"));
    }
}
