using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AlignStayAndRoomLifecycle : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "ResolutionNote",
                table: "MaintenanceRequests",
                type: "nvarchar(1000)",
                maxLength: 1000,
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "ResolvedAtUtc",
                table: "MaintenanceRequests",
                type: "datetime2(3)",
                precision: 3,
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "RequiresRoomInspection",
                table: "HotelProperties",
                type: "bit",
                nullable: false,
                defaultValue: true);

            migrationBuilder.AddColumn<string>(
                name: "IdentityDocumentType",
                table: "GuestStayRecords",
                type: "nvarchar(32)",
                maxLength: 32,
                nullable: true);

            migrationBuilder.AddColumn<DateOnly>(
                name: "IdentityExpiryDate",
                table: "GuestStayRecords",
                type: "date",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "IdentityIssuingCountry",
                table: "GuestStayRecords",
                type: "nvarchar(2)",
                maxLength: 2,
                nullable: true);

            migrationBuilder.Sql(
                """
                UPDATE [GuestStayRecords]
                SET [IdentityDocumentType] = N'LEGACY',
                    [IdentityDocumentNumber] = COALESCE(NULLIF(LTRIM(RTRIM([IdentityDocumentNumber])), N''), CONCAT(N'LEGACY-', CONVERT(nvarchar(36), [Id])))
                WHERE [IdentityDocumentType] IS NULL OR [IdentityDocumentNumber] IS NULL OR LTRIM(RTRIM([IdentityDocumentNumber])) = N'';
                """);

            migrationBuilder.AlterColumn<string>(
                name: "IdentityDocumentType",
                table: "GuestStayRecords",
                type: "nvarchar(32)",
                maxLength: 32,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(32)",
                oldMaxLength: 32,
                oldNullable: true);

            migrationBuilder.AlterColumn<string>(
                name: "IdentityDocumentNumber",
                table: "GuestStayRecords",
                type: "nvarchar(64)",
                maxLength: 64,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(64)",
                oldMaxLength: 64,
                oldNullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "ResolutionNote",
                table: "MaintenanceRequests");

            migrationBuilder.DropColumn(
                name: "ResolvedAtUtc",
                table: "MaintenanceRequests");

            migrationBuilder.DropColumn(
                name: "RequiresRoomInspection",
                table: "HotelProperties");

            migrationBuilder.DropColumn(
                name: "IdentityDocumentType",
                table: "GuestStayRecords");

            migrationBuilder.DropColumn(
                name: "IdentityExpiryDate",
                table: "GuestStayRecords");

            migrationBuilder.DropColumn(
                name: "IdentityIssuingCountry",
                table: "GuestStayRecords");

            migrationBuilder.AlterColumn<string>(
                name: "IdentityDocumentNumber",
                table: "GuestStayRecords",
                type: "nvarchar(64)",
                maxLength: 64,
                nullable: true,
                oldClrType: typeof(string),
                oldType: "nvarchar(64)",
                oldMaxLength: 64);
        }
    }
}
