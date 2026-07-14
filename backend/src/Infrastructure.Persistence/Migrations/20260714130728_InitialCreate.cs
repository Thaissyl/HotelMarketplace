using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable
#pragma warning disable CA1861

namespace Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class InitialCreate : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "Amenities",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Code = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    Name = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Amenities", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "UserAccounts",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Email = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: false),
                    PhoneNumber = table.Column<string>(type: "nvarchar(32)", maxLength: 32, nullable: true),
                    PasswordHash = table.Column<string>(type: "nvarchar(512)", maxLength: 512, nullable: false),
                    FullName = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    Status = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_UserAccounts", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "UserRoles",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Code = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    Name = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false),
                    Scope = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_UserRoles", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "HotelProperties",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    OwnerUserAccountId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Name = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    City = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    AddressLine = table.Column<string>(type: "nvarchar(300)", maxLength: 300, nullable: false),
                    ContactEmail = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: false),
                    ContactPhone = table.Column<string>(type: "nvarchar(32)", maxLength: 32, nullable: false),
                    Description = table.Column<string>(type: "nvarchar(2000)", maxLength: 2000, nullable: true),
                    ApprovalStatus = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    PublicationStatus = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    DefaultCommissionRate = table.Column<decimal>(type: "decimal(5,4)", precision: 5, scale: 4, nullable: false),
                    IsWalkInEnabled = table.Column<bool>(type: "bit", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_HotelProperties", x => x.Id);
                    table.CheckConstraint("CK_HotelProperties_DefaultCommissionRate", "[DefaultCommissionRate] >= 0 AND [DefaultCommissionRate] <= 0.30");
                    table.ForeignKey(
                        name: "FK_HotelProperties_UserAccounts_OwnerUserAccountId",
                        column: x => x.OwnerUserAccountId,
                        principalTable: "UserAccounts",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "UserAccountRoles",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UserAccountId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    RoleId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    IsActive = table.Column<bool>(type: "bit", nullable: false),
                    AssignedAtUtc = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_UserAccountRoles", x => x.Id);
                    table.ForeignKey(
                        name: "FK_UserAccountRoles_UserAccounts_UserAccountId",
                        column: x => x.UserAccountId,
                        principalTable: "UserAccounts",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_UserAccountRoles_UserRoles_RoleId",
                        column: x => x.RoleId,
                        principalTable: "UserRoles",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "AuditRecords",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    HotelId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    ActorUserAccountId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ActionType = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false),
                    TargetEntityType = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false),
                    TargetEntityId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Summary = table.Column<string>(type: "nvarchar(1000)", maxLength: 1000, nullable: false),
                    ActionTimestampUtc = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AuditRecords", x => x.Id);
                    table.ForeignKey(
                        name: "FK_AuditRecords_HotelProperties_HotelId",
                        column: x => x.HotelId,
                        principalTable: "HotelProperties",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_AuditRecords_UserAccounts_ActorUserAccountId",
                        column: x => x.ActorUserAccountId,
                        principalTable: "UserAccounts",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "Bookings",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    BookingCode = table.Column<string>(type: "nvarchar(32)", maxLength: 32, nullable: false),
                    CustomerUserAccountId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    HotelId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    CheckInDate = table.Column<DateOnly>(type: "date", nullable: false),
                    CheckOutDate = table.Column<DateOnly>(type: "date", nullable: false),
                    PaymentMode = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    Source = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    Status = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    TotalAmount = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    GuestFullName = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    GuestPhone = table.Column<string>(type: "nvarchar(32)", maxLength: 32, nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false),
                    PaymentExpiresAtUtc = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Bookings", x => x.Id);
                    table.CheckConstraint("CK_Bookings_StayDates", "[CheckOutDate] > [CheckInDate]");
                    table.CheckConstraint("CK_Bookings_TotalAmount", "[TotalAmount] >= 0");
                    table.ForeignKey(
                        name: "FK_Bookings_HotelProperties_HotelId",
                        column: x => x.HotelId,
                        principalTable: "HotelProperties",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_Bookings_UserAccounts_CustomerUserAccountId",
                        column: x => x.CustomerUserAccountId,
                        principalTable: "UserAccounts",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "CancellationPolicies",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    HotelId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Name = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false),
                    FreeCancellationHours = table.Column<int>(type: "int", nullable: false),
                    RefundPercentage = table.Column<decimal>(type: "decimal(5,2)", precision: 5, scale: 2, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_CancellationPolicies", x => x.Id);
                    table.CheckConstraint("CK_CancellationPolicies_FreeCancellationHours", "[FreeCancellationHours] >= 0");
                    table.CheckConstraint("CK_CancellationPolicies_RefundPercentage", "[RefundPercentage] >= 0 AND [RefundPercentage] <= 100");
                    table.ForeignKey(
                        name: "FK_CancellationPolicies_HotelProperties_HotelId",
                        column: x => x.HotelId,
                        principalTable: "HotelProperties",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "HotelAmenities",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    HotelId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    AmenityId = table.Column<Guid>(type: "uniqueidentifier", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_HotelAmenities", x => x.Id);
                    table.ForeignKey(
                        name: "FK_HotelAmenities_Amenities_AmenityId",
                        column: x => x.AmenityId,
                        principalTable: "Amenities",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_HotelAmenities_HotelProperties_HotelId",
                        column: x => x.HotelId,
                        principalTable: "HotelProperties",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "HotelImages",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    HotelId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ImageUrl = table.Column<string>(type: "nvarchar(1000)", maxLength: 1000, nullable: false),
                    DisplayOrder = table.Column<int>(type: "int", nullable: false),
                    Status = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_HotelImages", x => x.Id);
                    table.ForeignKey(
                        name: "FK_HotelImages_HotelProperties_HotelId",
                        column: x => x.HotelId,
                        principalTable: "HotelProperties",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "HotelStaffAssignments",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UserAccountId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    HotelId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    RoleId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    AssignedByUserAccountId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    IsActive = table.Column<bool>(type: "bit", nullable: false),
                    AssignedAtUtc = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_HotelStaffAssignments", x => x.Id);
                    table.ForeignKey(
                        name: "FK_HotelStaffAssignments_HotelProperties_HotelId",
                        column: x => x.HotelId,
                        principalTable: "HotelProperties",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_HotelStaffAssignments_UserAccounts_AssignedByUserAccountId",
                        column: x => x.AssignedByUserAccountId,
                        principalTable: "UserAccounts",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_HotelStaffAssignments_UserAccounts_UserAccountId",
                        column: x => x.UserAccountId,
                        principalTable: "UserAccounts",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_HotelStaffAssignments_UserRoles_RoleId",
                        column: x => x.RoleId,
                        principalTable: "UserRoles",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "NotificationRecords",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    HotelId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    RecipientUserAccountId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    EventType = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false),
                    RelatedEntityType = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false),
                    RelatedEntityId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Message = table.Column<string>(type: "nvarchar(1000)", maxLength: 1000, nullable: false),
                    Status = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_NotificationRecords", x => x.Id);
                    table.ForeignKey(
                        name: "FK_NotificationRecords_HotelProperties_HotelId",
                        column: x => x.HotelId,
                        principalTable: "HotelProperties",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_NotificationRecords_UserAccounts_RecipientUserAccountId",
                        column: x => x.RecipientUserAccountId,
                        principalTable: "UserAccounts",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "RoomTypes",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    HotelId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Name = table.Column<string>(type: "nvarchar(160)", maxLength: 160, nullable: false),
                    AdultCapacity = table.Column<int>(type: "int", nullable: false),
                    ChildCapacity = table.Column<int>(type: "int", nullable: false),
                    BasePricePerNight = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    Description = table.Column<string>(type: "nvarchar(1000)", maxLength: 1000, nullable: true),
                    Status = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RoomTypes", x => x.Id);
                    table.CheckConstraint("CK_RoomTypes_AdultCapacity", "[AdultCapacity] > 0");
                    table.CheckConstraint("CK_RoomTypes_BasePricePerNight", "[BasePricePerNight] >= 0");
                    table.CheckConstraint("CK_RoomTypes_ChildCapacity", "[ChildCapacity] >= 0");
                    table.ForeignKey(
                        name: "FK_RoomTypes_HotelProperties_HotelId",
                        column: x => x.HotelId,
                        principalTable: "HotelProperties",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "SettlementRecords",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    HotelId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    SettlementType = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    TotalAmount = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    Status = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    AdminNote = table.Column<string>(type: "nvarchar(1000)", maxLength: 1000, nullable: true),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SettlementRecords", x => x.Id);
                    table.CheckConstraint("CK_SettlementRecords_TotalAmount", "[TotalAmount] >= 0");
                    table.ForeignKey(
                        name: "FK_SettlementRecords_HotelProperties_HotelId",
                        column: x => x.HotelId,
                        principalTable: "HotelProperties",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "StaffInvitations",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    HotelId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    RoleId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Email = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: false),
                    InvitedByUserAccountId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Status = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    InvitedAtUtc = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false),
                    ExpiresAtUtc = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_StaffInvitations", x => x.Id);
                    table.ForeignKey(
                        name: "FK_StaffInvitations_HotelProperties_HotelId",
                        column: x => x.HotelId,
                        principalTable: "HotelProperties",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_StaffInvitations_UserAccounts_InvitedByUserAccountId",
                        column: x => x.InvitedByUserAccountId,
                        principalTable: "UserAccounts",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_StaffInvitations_UserRoles_RoleId",
                        column: x => x.RoleId,
                        principalTable: "UserRoles",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "CommissionRecords",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    HotelId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    BookingId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    BaseAmount = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    CommissionRate = table.Column<decimal>(type: "decimal(5,4)", precision: 5, scale: 4, nullable: false),
                    CommissionAmount = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_CommissionRecords", x => x.Id);
                    table.CheckConstraint("CK_CommissionRecords_BaseAmount", "[BaseAmount] >= 0");
                    table.CheckConstraint("CK_CommissionRecords_CommissionAmount", "[CommissionAmount] >= 0");
                    table.CheckConstraint("CK_CommissionRecords_CommissionRate", "[CommissionRate] >= 0 AND [CommissionRate] <= 0.30");
                    table.ForeignKey(
                        name: "FK_CommissionRecords_Bookings_BookingId",
                        column: x => x.BookingId,
                        principalTable: "Bookings",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_CommissionRecords_HotelProperties_HotelId",
                        column: x => x.HotelId,
                        principalTable: "HotelProperties",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "GuestStayRecords",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    HotelId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    BookingId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    CheckedInByUserAccountId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    CheckedOutByUserAccountId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    GuestFullName = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    IdentityDocumentNumber = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: true),
                    CheckedInAtUtc = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false),
                    CheckedOutAtUtc = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_GuestStayRecords", x => x.Id);
                    table.ForeignKey(
                        name: "FK_GuestStayRecords_Bookings_BookingId",
                        column: x => x.BookingId,
                        principalTable: "Bookings",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_GuestStayRecords_HotelProperties_HotelId",
                        column: x => x.HotelId,
                        principalTable: "HotelProperties",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_GuestStayRecords_UserAccounts_CheckedInByUserAccountId",
                        column: x => x.CheckedInByUserAccountId,
                        principalTable: "UserAccounts",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_GuestStayRecords_UserAccounts_CheckedOutByUserAccountId",
                        column: x => x.CheckedOutByUserAccountId,
                        principalTable: "UserAccounts",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "Invoices",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    HotelId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    BookingId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    InvoiceNumber = table.Column<string>(type: "nvarchar(32)", maxLength: 32, nullable: false),
                    RoomAmount = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    PaidAmount = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    Status = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    IssuedAtUtc = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Invoices", x => x.Id);
                    table.CheckConstraint("CK_Invoices_PaidAmount", "[PaidAmount] >= 0");
                    table.CheckConstraint("CK_Invoices_RoomAmount", "[RoomAmount] >= 0");
                    table.ForeignKey(
                        name: "FK_Invoices_Bookings_BookingId",
                        column: x => x.BookingId,
                        principalTable: "Bookings",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_Invoices_HotelProperties_HotelId",
                        column: x => x.HotelId,
                        principalTable: "HotelProperties",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "PaymentCollectionRecords",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    HotelId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    BookingId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    CollectedByUserAccountId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Amount = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    Status = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    CollectedAtUtc = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PaymentCollectionRecords", x => x.Id);
                    table.CheckConstraint("CK_PaymentCollectionRecords_Amount", "[Amount] >= 0");
                    table.ForeignKey(
                        name: "FK_PaymentCollectionRecords_Bookings_BookingId",
                        column: x => x.BookingId,
                        principalTable: "Bookings",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_PaymentCollectionRecords_HotelProperties_HotelId",
                        column: x => x.HotelId,
                        principalTable: "HotelProperties",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_PaymentCollectionRecords_UserAccounts_CollectedByUserAccountId",
                        column: x => x.CollectedByUserAccountId,
                        principalTable: "UserAccounts",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "PaymentTransactions",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    HotelId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    BookingId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Provider = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    GatewayReference = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: true),
                    Amount = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    Status = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    ReconciliationStatus = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PaymentTransactions", x => x.Id);
                    table.CheckConstraint("CK_PaymentTransactions_Amount", "[Amount] >= 0");
                    table.ForeignKey(
                        name: "FK_PaymentTransactions_Bookings_BookingId",
                        column: x => x.BookingId,
                        principalTable: "Bookings",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_PaymentTransactions_HotelProperties_HotelId",
                        column: x => x.HotelId,
                        principalTable: "HotelProperties",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "RefundRecords",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    HotelId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    BookingId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    RequestedAmount = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    ApprovedAmount = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    Reason = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: false),
                    Status = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RefundRecords", x => x.Id);
                    table.CheckConstraint("CK_RefundRecords_ApprovedAmount", "[ApprovedAmount] >= 0 AND [ApprovedAmount] <= [RequestedAmount]");
                    table.CheckConstraint("CK_RefundRecords_RequestedAmount", "[RequestedAmount] >= 0");
                    table.ForeignKey(
                        name: "FK_RefundRecords_Bookings_BookingId",
                        column: x => x.BookingId,
                        principalTable: "Bookings",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_RefundRecords_HotelProperties_HotelId",
                        column: x => x.HotelId,
                        principalTable: "HotelProperties",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "BookingRooms",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    BookingId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    RoomTypeId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Quantity = table.Column<int>(type: "int", nullable: false),
                    Nights = table.Column<int>(type: "int", nullable: false),
                    UnitPricePerNight = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    LineAmount = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_BookingRooms", x => x.Id);
                    table.CheckConstraint("CK_BookingRooms_LineAmount", "[LineAmount] >= 0");
                    table.CheckConstraint("CK_BookingRooms_Nights", "[Nights] > 0");
                    table.CheckConstraint("CK_BookingRooms_Quantity", "[Quantity] > 0");
                    table.CheckConstraint("CK_BookingRooms_UnitPricePerNight", "[UnitPricePerNight] >= 0");
                    table.ForeignKey(
                        name: "FK_BookingRooms_Bookings_BookingId",
                        column: x => x.BookingId,
                        principalTable: "Bookings",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_BookingRooms_RoomTypes_RoomTypeId",
                        column: x => x.RoomTypeId,
                        principalTable: "RoomTypes",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "PhysicalRooms",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    HotelId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    RoomTypeId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    RoomNumber = table.Column<string>(type: "nvarchar(32)", maxLength: 32, nullable: false),
                    Status = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PhysicalRooms", x => x.Id);
                    table.ForeignKey(
                        name: "FK_PhysicalRooms_HotelProperties_HotelId",
                        column: x => x.HotelId,
                        principalTable: "HotelProperties",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_PhysicalRooms_RoomTypes_RoomTypeId",
                        column: x => x.RoomTypeId,
                        principalTable: "RoomTypes",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "SettlementItems",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    HotelId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    SettlementRecordId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    BookingId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    CommissionRecordId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    PaymentTransactionId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    Amount = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    Status = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SettlementItems", x => x.Id);
                    table.CheckConstraint("CK_SettlementItems_Amount", "[Amount] >= 0");
                    table.ForeignKey(
                        name: "FK_SettlementItems_Bookings_BookingId",
                        column: x => x.BookingId,
                        principalTable: "Bookings",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_SettlementItems_CommissionRecords_CommissionRecordId",
                        column: x => x.CommissionRecordId,
                        principalTable: "CommissionRecords",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_SettlementItems_HotelProperties_HotelId",
                        column: x => x.HotelId,
                        principalTable: "HotelProperties",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_SettlementItems_PaymentTransactions_PaymentTransactionId",
                        column: x => x.PaymentTransactionId,
                        principalTable: "PaymentTransactions",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_SettlementItems_SettlementRecords_SettlementRecordId",
                        column: x => x.SettlementRecordId,
                        principalTable: "SettlementRecords",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "BookingRoomAssignments",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    HotelId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    BookingId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    BookingRoomId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    PhysicalRoomId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    StartDate = table.Column<DateOnly>(type: "date", nullable: false),
                    EndDate = table.Column<DateOnly>(type: "date", nullable: false),
                    AssignedByUserAccountId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Status = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    AssignedAtUtc = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_BookingRoomAssignments", x => x.Id);
                    table.CheckConstraint("CK_BookingRoomAssignments_DateRange", "[EndDate] > [StartDate]");
                    table.ForeignKey(
                        name: "FK_BookingRoomAssignments_BookingRooms_BookingRoomId",
                        column: x => x.BookingRoomId,
                        principalTable: "BookingRooms",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_BookingRoomAssignments_Bookings_BookingId",
                        column: x => x.BookingId,
                        principalTable: "Bookings",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_BookingRoomAssignments_HotelProperties_HotelId",
                        column: x => x.HotelId,
                        principalTable: "HotelProperties",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_BookingRoomAssignments_PhysicalRooms_PhysicalRoomId",
                        column: x => x.PhysicalRoomId,
                        principalTable: "PhysicalRooms",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_BookingRoomAssignments_UserAccounts_AssignedByUserAccountId",
                        column: x => x.AssignedByUserAccountId,
                        principalTable: "UserAccounts",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "HousekeepingTasks",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    HotelId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    PhysicalRoomId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    BookingId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    AssignedToUserAccountId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    TaskType = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    Status = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_HousekeepingTasks", x => x.Id);
                    table.ForeignKey(
                        name: "FK_HousekeepingTasks_Bookings_BookingId",
                        column: x => x.BookingId,
                        principalTable: "Bookings",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_HousekeepingTasks_HotelProperties_HotelId",
                        column: x => x.HotelId,
                        principalTable: "HotelProperties",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_HousekeepingTasks_PhysicalRooms_PhysicalRoomId",
                        column: x => x.PhysicalRoomId,
                        principalTable: "PhysicalRooms",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_HousekeepingTasks_UserAccounts_AssignedToUserAccountId",
                        column: x => x.AssignedToUserAccountId,
                        principalTable: "UserAccounts",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "MaintenanceRequests",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    HotelId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    PhysicalRoomId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ReportedByUserAccountId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    AssignedToUserAccountId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    Description = table.Column<string>(type: "nvarchar(1000)", maxLength: 1000, nullable: false),
                    Severity = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    Status = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_MaintenanceRequests", x => x.Id);
                    table.ForeignKey(
                        name: "FK_MaintenanceRequests_HotelProperties_HotelId",
                        column: x => x.HotelId,
                        principalTable: "HotelProperties",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_MaintenanceRequests_PhysicalRooms_PhysicalRoomId",
                        column: x => x.PhysicalRoomId,
                        principalTable: "PhysicalRooms",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_MaintenanceRequests_UserAccounts_AssignedToUserAccountId",
                        column: x => x.AssignedToUserAccountId,
                        principalTable: "UserAccounts",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_MaintenanceRequests_UserAccounts_ReportedByUserAccountId",
                        column: x => x.ReportedByUserAccountId,
                        principalTable: "UserAccounts",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "RoomAvailabilities",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    HotelId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    RoomTypeId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    PhysicalRoomId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    StartDate = table.Column<DateOnly>(type: "date", nullable: false),
                    EndDate = table.Column<DateOnly>(type: "date", nullable: false),
                    Status = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RoomAvailabilities", x => x.Id);
                    table.CheckConstraint("CK_RoomAvailabilities_DateRange", "[EndDate] > [StartDate]");
                    table.ForeignKey(
                        name: "FK_RoomAvailabilities_HotelProperties_HotelId",
                        column: x => x.HotelId,
                        principalTable: "HotelProperties",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_RoomAvailabilities_PhysicalRooms_PhysicalRoomId",
                        column: x => x.PhysicalRoomId,
                        principalTable: "PhysicalRooms",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_RoomAvailabilities_RoomTypes_RoomTypeId",
                        column: x => x.RoomTypeId,
                        principalTable: "RoomTypes",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "RoomStatusHistories",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    HotelId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    PhysicalRoomId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    OldStatus = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    NewStatus = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    ChangedByUserAccountId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    ChangedAtUtc = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RoomStatusHistories", x => x.Id);
                    table.ForeignKey(
                        name: "FK_RoomStatusHistories_HotelProperties_HotelId",
                        column: x => x.HotelId,
                        principalTable: "HotelProperties",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_RoomStatusHistories_PhysicalRooms_PhysicalRoomId",
                        column: x => x.PhysicalRoomId,
                        principalTable: "PhysicalRooms",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_RoomStatusHistories_UserAccounts_ChangedByUserAccountId",
                        column: x => x.ChangedByUserAccountId,
                        principalTable: "UserAccounts",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Amenities_Code",
                table: "Amenities",
                column: "Code",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_AuditRecords_ActorUserAccountId",
                table: "AuditRecords",
                column: "ActorUserAccountId");

            migrationBuilder.CreateIndex(
                name: "IX_AuditRecords_HotelId_ActionTimestampUtc",
                table: "AuditRecords",
                columns: new[] { "HotelId", "ActionTimestampUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_AuditRecords_TargetEntityType_TargetEntityId_ActionTimestampUtc",
                table: "AuditRecords",
                columns: new[] { "TargetEntityType", "TargetEntityId", "ActionTimestampUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_BookingRoomAssignments_AssignedByUserAccountId",
                table: "BookingRoomAssignments",
                column: "AssignedByUserAccountId");

            migrationBuilder.CreateIndex(
                name: "IX_BookingRoomAssignments_BookingId",
                table: "BookingRoomAssignments",
                column: "BookingId");

            migrationBuilder.CreateIndex(
                name: "IX_BookingRoomAssignments_BookingRoomId",
                table: "BookingRoomAssignments",
                column: "BookingRoomId");

            migrationBuilder.CreateIndex(
                name: "IX_BookingRoomAssignments_HotelId_BookingId",
                table: "BookingRoomAssignments",
                columns: new[] { "HotelId", "BookingId" });

            migrationBuilder.CreateIndex(
                name: "IX_BookingRoomAssignments_PhysicalRoomId_StartDate_EndDate_Status",
                table: "BookingRoomAssignments",
                columns: new[] { "PhysicalRoomId", "StartDate", "EndDate", "Status" });

            migrationBuilder.CreateIndex(
                name: "IX_BookingRooms_BookingId",
                table: "BookingRooms",
                column: "BookingId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_BookingRooms_RoomTypeId",
                table: "BookingRooms",
                column: "RoomTypeId");

            migrationBuilder.CreateIndex(
                name: "IX_Bookings_BookingCode",
                table: "Bookings",
                column: "BookingCode",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Bookings_CustomerUserAccountId_CreatedAtUtc",
                table: "Bookings",
                columns: new[] { "CustomerUserAccountId", "CreatedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_Bookings_HotelId_CheckInDate_CheckOutDate_Status",
                table: "Bookings",
                columns: new[] { "HotelId", "CheckInDate", "CheckOutDate", "Status" });

            migrationBuilder.CreateIndex(
                name: "IX_CancellationPolicies_HotelId",
                table: "CancellationPolicies",
                column: "HotelId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_CommissionRecords_BookingId",
                table: "CommissionRecords",
                column: "BookingId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_CommissionRecords_HotelId",
                table: "CommissionRecords",
                column: "HotelId");

            migrationBuilder.CreateIndex(
                name: "IX_GuestStayRecords_BookingId",
                table: "GuestStayRecords",
                column: "BookingId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_GuestStayRecords_CheckedInByUserAccountId",
                table: "GuestStayRecords",
                column: "CheckedInByUserAccountId");

            migrationBuilder.CreateIndex(
                name: "IX_GuestStayRecords_CheckedOutByUserAccountId",
                table: "GuestStayRecords",
                column: "CheckedOutByUserAccountId");

            migrationBuilder.CreateIndex(
                name: "IX_GuestStayRecords_HotelId_CheckedInAtUtc",
                table: "GuestStayRecords",
                columns: new[] { "HotelId", "CheckedInAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_HotelAmenities_AmenityId",
                table: "HotelAmenities",
                column: "AmenityId");

            migrationBuilder.CreateIndex(
                name: "IX_HotelAmenities_HotelId_AmenityId",
                table: "HotelAmenities",
                columns: new[] { "HotelId", "AmenityId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_HotelImages_HotelId_DisplayOrder",
                table: "HotelImages",
                columns: new[] { "HotelId", "DisplayOrder" });

            migrationBuilder.CreateIndex(
                name: "IX_HotelProperties_City_ApprovalStatus_PublicationStatus",
                table: "HotelProperties",
                columns: new[] { "City", "ApprovalStatus", "PublicationStatus" });

            migrationBuilder.CreateIndex(
                name: "IX_HotelProperties_OwnerUserAccountId",
                table: "HotelProperties",
                column: "OwnerUserAccountId");

            migrationBuilder.CreateIndex(
                name: "IX_HotelStaffAssignments_AssignedByUserAccountId",
                table: "HotelStaffAssignments",
                column: "AssignedByUserAccountId");

            migrationBuilder.CreateIndex(
                name: "IX_HotelStaffAssignments_HotelId",
                table: "HotelStaffAssignments",
                column: "HotelId");

            migrationBuilder.CreateIndex(
                name: "IX_HotelStaffAssignments_RoleId",
                table: "HotelStaffAssignments",
                column: "RoleId");

            migrationBuilder.CreateIndex(
                name: "IX_HotelStaffAssignments_UserAccountId_HotelId_RoleId",
                table: "HotelStaffAssignments",
                columns: new[] { "UserAccountId", "HotelId", "RoleId" },
                unique: true,
                filter: "[IsActive] = 1");

            migrationBuilder.CreateIndex(
                name: "IX_HousekeepingTasks_AssignedToUserAccountId",
                table: "HousekeepingTasks",
                column: "AssignedToUserAccountId");

            migrationBuilder.CreateIndex(
                name: "IX_HousekeepingTasks_BookingId",
                table: "HousekeepingTasks",
                column: "BookingId");

            migrationBuilder.CreateIndex(
                name: "IX_HousekeepingTasks_HotelId_Status_AssignedToUserAccountId",
                table: "HousekeepingTasks",
                columns: new[] { "HotelId", "Status", "AssignedToUserAccountId" });

            migrationBuilder.CreateIndex(
                name: "IX_HousekeepingTasks_PhysicalRoomId",
                table: "HousekeepingTasks",
                column: "PhysicalRoomId");

            migrationBuilder.CreateIndex(
                name: "IX_Invoices_BookingId",
                table: "Invoices",
                column: "BookingId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Invoices_HotelId",
                table: "Invoices",
                column: "HotelId");

            migrationBuilder.CreateIndex(
                name: "IX_Invoices_InvoiceNumber",
                table: "Invoices",
                column: "InvoiceNumber",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_MaintenanceRequests_AssignedToUserAccountId",
                table: "MaintenanceRequests",
                column: "AssignedToUserAccountId");

            migrationBuilder.CreateIndex(
                name: "IX_MaintenanceRequests_HotelId_Status_AssignedToUserAccountId",
                table: "MaintenanceRequests",
                columns: new[] { "HotelId", "Status", "AssignedToUserAccountId" });

            migrationBuilder.CreateIndex(
                name: "IX_MaintenanceRequests_PhysicalRoomId",
                table: "MaintenanceRequests",
                column: "PhysicalRoomId");

            migrationBuilder.CreateIndex(
                name: "IX_MaintenanceRequests_ReportedByUserAccountId",
                table: "MaintenanceRequests",
                column: "ReportedByUserAccountId");

            migrationBuilder.CreateIndex(
                name: "IX_NotificationRecords_HotelId_Status",
                table: "NotificationRecords",
                columns: new[] { "HotelId", "Status" });

            migrationBuilder.CreateIndex(
                name: "IX_NotificationRecords_RecipientUserAccountId",
                table: "NotificationRecords",
                column: "RecipientUserAccountId");

            migrationBuilder.CreateIndex(
                name: "IX_NotificationRecords_RelatedEntityType_RelatedEntityId",
                table: "NotificationRecords",
                columns: new[] { "RelatedEntityType", "RelatedEntityId" });

            migrationBuilder.CreateIndex(
                name: "IX_PaymentCollectionRecords_BookingId_Status",
                table: "PaymentCollectionRecords",
                columns: new[] { "BookingId", "Status" });

            migrationBuilder.CreateIndex(
                name: "IX_PaymentCollectionRecords_CollectedByUserAccountId",
                table: "PaymentCollectionRecords",
                column: "CollectedByUserAccountId");

            migrationBuilder.CreateIndex(
                name: "IX_PaymentCollectionRecords_HotelId",
                table: "PaymentCollectionRecords",
                column: "HotelId");

            migrationBuilder.CreateIndex(
                name: "IX_PaymentTransactions_BookingId",
                table: "PaymentTransactions",
                column: "BookingId");

            migrationBuilder.CreateIndex(
                name: "IX_PaymentTransactions_GatewayReference",
                table: "PaymentTransactions",
                column: "GatewayReference",
                unique: true,
                filter: "[GatewayReference] IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_PaymentTransactions_HotelId_Status_ReconciliationStatus",
                table: "PaymentTransactions",
                columns: new[] { "HotelId", "Status", "ReconciliationStatus" });

            migrationBuilder.CreateIndex(
                name: "IX_PhysicalRooms_HotelId_RoomNumber",
                table: "PhysicalRooms",
                columns: new[] { "HotelId", "RoomNumber" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_PhysicalRooms_HotelId_RoomTypeId_Status",
                table: "PhysicalRooms",
                columns: new[] { "HotelId", "RoomTypeId", "Status" });

            migrationBuilder.CreateIndex(
                name: "IX_PhysicalRooms_RoomTypeId",
                table: "PhysicalRooms",
                column: "RoomTypeId");

            migrationBuilder.CreateIndex(
                name: "IX_RefundRecords_BookingId",
                table: "RefundRecords",
                column: "BookingId");

            migrationBuilder.CreateIndex(
                name: "IX_RefundRecords_HotelId_Status",
                table: "RefundRecords",
                columns: new[] { "HotelId", "Status" });

            migrationBuilder.CreateIndex(
                name: "IX_RoomAvailabilities_HotelId_RoomTypeId_StartDate_EndDate_Status",
                table: "RoomAvailabilities",
                columns: new[] { "HotelId", "RoomTypeId", "StartDate", "EndDate", "Status" });

            migrationBuilder.CreateIndex(
                name: "IX_RoomAvailabilities_PhysicalRoomId",
                table: "RoomAvailabilities",
                column: "PhysicalRoomId");

            migrationBuilder.CreateIndex(
                name: "IX_RoomAvailabilities_RoomTypeId",
                table: "RoomAvailabilities",
                column: "RoomTypeId");

            migrationBuilder.CreateIndex(
                name: "IX_RoomStatusHistories_ChangedByUserAccountId",
                table: "RoomStatusHistories",
                column: "ChangedByUserAccountId");

            migrationBuilder.CreateIndex(
                name: "IX_RoomStatusHistories_HotelId",
                table: "RoomStatusHistories",
                column: "HotelId");

            migrationBuilder.CreateIndex(
                name: "IX_RoomStatusHistories_PhysicalRoomId_ChangedAtUtc",
                table: "RoomStatusHistories",
                columns: new[] { "PhysicalRoomId", "ChangedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_RoomTypes_HotelId_Status",
                table: "RoomTypes",
                columns: new[] { "HotelId", "Status" });

            migrationBuilder.CreateIndex(
                name: "IX_SettlementItems_BookingId",
                table: "SettlementItems",
                column: "BookingId");

            migrationBuilder.CreateIndex(
                name: "IX_SettlementItems_CommissionRecordId",
                table: "SettlementItems",
                column: "CommissionRecordId");

            migrationBuilder.CreateIndex(
                name: "IX_SettlementItems_HotelId",
                table: "SettlementItems",
                column: "HotelId");

            migrationBuilder.CreateIndex(
                name: "IX_SettlementItems_PaymentTransactionId",
                table: "SettlementItems",
                column: "PaymentTransactionId");

            migrationBuilder.CreateIndex(
                name: "IX_SettlementItems_SettlementRecordId",
                table: "SettlementItems",
                column: "SettlementRecordId");

            migrationBuilder.CreateIndex(
                name: "IX_SettlementRecords_HotelId_Status",
                table: "SettlementRecords",
                columns: new[] { "HotelId", "Status" });

            migrationBuilder.CreateIndex(
                name: "IX_StaffInvitations_HotelId_Email_RoleId",
                table: "StaffInvitations",
                columns: new[] { "HotelId", "Email", "RoleId" },
                filter: "[Status] = 'Active'");

            migrationBuilder.CreateIndex(
                name: "IX_StaffInvitations_InvitedByUserAccountId",
                table: "StaffInvitations",
                column: "InvitedByUserAccountId");

            migrationBuilder.CreateIndex(
                name: "IX_StaffInvitations_RoleId",
                table: "StaffInvitations",
                column: "RoleId");

            migrationBuilder.CreateIndex(
                name: "IX_UserAccountRoles_RoleId",
                table: "UserAccountRoles",
                column: "RoleId");

            migrationBuilder.CreateIndex(
                name: "IX_UserAccountRoles_UserAccountId_RoleId",
                table: "UserAccountRoles",
                columns: new[] { "UserAccountId", "RoleId" },
                unique: true,
                filter: "[IsActive] = 1");

            migrationBuilder.CreateIndex(
                name: "IX_UserAccounts_Email",
                table: "UserAccounts",
                column: "Email",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_UserAccounts_PhoneNumber",
                table: "UserAccounts",
                column: "PhoneNumber",
                unique: true,
                filter: "[PhoneNumber] IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_UserRoles_Code",
                table: "UserRoles",
                column: "Code",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "AuditRecords");

            migrationBuilder.DropTable(
                name: "BookingRoomAssignments");

            migrationBuilder.DropTable(
                name: "CancellationPolicies");

            migrationBuilder.DropTable(
                name: "GuestStayRecords");

            migrationBuilder.DropTable(
                name: "HotelAmenities");

            migrationBuilder.DropTable(
                name: "HotelImages");

            migrationBuilder.DropTable(
                name: "HotelStaffAssignments");

            migrationBuilder.DropTable(
                name: "HousekeepingTasks");

            migrationBuilder.DropTable(
                name: "Invoices");

            migrationBuilder.DropTable(
                name: "MaintenanceRequests");

            migrationBuilder.DropTable(
                name: "NotificationRecords");

            migrationBuilder.DropTable(
                name: "PaymentCollectionRecords");

            migrationBuilder.DropTable(
                name: "RefundRecords");

            migrationBuilder.DropTable(
                name: "RoomAvailabilities");

            migrationBuilder.DropTable(
                name: "RoomStatusHistories");

            migrationBuilder.DropTable(
                name: "SettlementItems");

            migrationBuilder.DropTable(
                name: "StaffInvitations");

            migrationBuilder.DropTable(
                name: "UserAccountRoles");

            migrationBuilder.DropTable(
                name: "BookingRooms");

            migrationBuilder.DropTable(
                name: "Amenities");

            migrationBuilder.DropTable(
                name: "PhysicalRooms");

            migrationBuilder.DropTable(
                name: "CommissionRecords");

            migrationBuilder.DropTable(
                name: "PaymentTransactions");

            migrationBuilder.DropTable(
                name: "SettlementRecords");

            migrationBuilder.DropTable(
                name: "UserRoles");

            migrationBuilder.DropTable(
                name: "RoomTypes");

            migrationBuilder.DropTable(
                name: "Bookings");

            migrationBuilder.DropTable(
                name: "HotelProperties");

            migrationBuilder.DropTable(
                name: "UserAccounts");
        }
    }
}
