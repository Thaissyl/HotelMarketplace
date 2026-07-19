using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddBookingCancellationAndNoShow : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_RefundRecords_BookingId",
                table: "RefundRecords");

            migrationBuilder.AddColumn<string>(
                name: "CancellationReason",
                table: "Bookings",
                type: "nvarchar(500)",
                maxLength: 500,
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "CancelledAtUtc",
                table: "Bookings",
                type: "datetime2(3)",
                precision: 3,
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "NoShowAtUtc",
                table: "Bookings",
                type: "datetime2(3)",
                precision: 3,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "NoShowReason",
                table: "Bookings",
                type: "nvarchar(500)",
                maxLength: 500,
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_RefundRecords_BookingId",
                table: "RefundRecords",
                column: "BookingId",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_RefundRecords_BookingId",
                table: "RefundRecords");

            migrationBuilder.DropColumn(
                name: "CancellationReason",
                table: "Bookings");

            migrationBuilder.DropColumn(
                name: "CancelledAtUtc",
                table: "Bookings");

            migrationBuilder.DropColumn(
                name: "NoShowAtUtc",
                table: "Bookings");

            migrationBuilder.DropColumn(
                name: "NoShowReason",
                table: "Bookings");

            migrationBuilder.CreateIndex(
                name: "IX_RefundRecords_BookingId",
                table: "RefundRecords",
                column: "BookingId");
        }
    }
}
