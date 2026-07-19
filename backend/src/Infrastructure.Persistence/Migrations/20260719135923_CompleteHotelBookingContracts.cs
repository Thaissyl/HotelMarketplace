using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class CompleteHotelBookingContracts : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "Facilities",
                table: "RoomTypes",
                type: "nvarchar(2000)",
                maxLength: 2000,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Floor",
                table: "PhysicalRooms",
                type: "nvarchar(20)",
                maxLength: 20,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Notes",
                table: "PhysicalRooms",
                type: "nvarchar(500)",
                maxLength: 500,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Description",
                table: "CancellationPolicies",
                type: "nvarchar(1000)",
                maxLength: 1000,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Status",
                table: "CancellationPolicies",
                type: "nvarchar(64)",
                maxLength: 64,
                nullable: false,
                defaultValue: "Active");

            migrationBuilder.AddColumn<int>(
                name: "CancellationPolicyFreeCancellationHours",
                table: "Bookings",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "CancellationPolicyName",
                table: "Bookings",
                type: "nvarchar(128)",
                maxLength: 128,
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "CancellationPolicyRefundPercentage",
                table: "Bookings",
                type: "decimal(5,2)",
                precision: 5,
                scale: 2,
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "GuestCount",
                table: "Bookings",
                type: "int",
                nullable: false,
                defaultValue: 1);

            migrationBuilder.AddColumn<string>(
                name: "Status",
                table: "Amenities",
                type: "nvarchar(64)",
                maxLength: 64,
                nullable: false,
                defaultValue: "Active");

            migrationBuilder.AddColumn<string>(
                name: "Type",
                table: "Amenities",
                type: "nvarchar(64)",
                maxLength: 64,
                nullable: false,
                defaultValue: "General");

            migrationBuilder.Sql(
                """
                UPDATE booking
                SET booking.CancellationPolicyName = policy.Name,
                    booking.CancellationPolicyFreeCancellationHours = policy.FreeCancellationHours,
                    booking.CancellationPolicyRefundPercentage = policy.RefundPercentage
                FROM Bookings AS booking
                INNER JOIN CancellationPolicies AS policy ON policy.HotelId = booking.HotelId;
                """);

            migrationBuilder.AddCheckConstraint(
                name: "CK_Bookings_GuestCount",
                table: "Bookings",
                sql: "[GuestCount] > 0");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "CK_Bookings_GuestCount",
                table: "Bookings");

            migrationBuilder.DropColumn(
                name: "Facilities",
                table: "RoomTypes");

            migrationBuilder.DropColumn(
                name: "Floor",
                table: "PhysicalRooms");

            migrationBuilder.DropColumn(
                name: "Notes",
                table: "PhysicalRooms");

            migrationBuilder.DropColumn(
                name: "Description",
                table: "CancellationPolicies");

            migrationBuilder.DropColumn(
                name: "Status",
                table: "CancellationPolicies");

            migrationBuilder.DropColumn(
                name: "CancellationPolicyFreeCancellationHours",
                table: "Bookings");

            migrationBuilder.DropColumn(
                name: "CancellationPolicyName",
                table: "Bookings");

            migrationBuilder.DropColumn(
                name: "CancellationPolicyRefundPercentage",
                table: "Bookings");

            migrationBuilder.DropColumn(
                name: "GuestCount",
                table: "Bookings");

            migrationBuilder.DropColumn(
                name: "Status",
                table: "Amenities");

            migrationBuilder.DropColumn(
                name: "Type",
                table: "Amenities");
        }
    }
}
