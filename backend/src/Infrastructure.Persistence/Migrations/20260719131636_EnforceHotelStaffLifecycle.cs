using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1861

namespace Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class EnforceHotelStaffLifecycle : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_HotelStaffAssignments_UserAccountId_HotelId_RoleId",
                table: "HotelStaffAssignments");

            migrationBuilder.Sql(
                """
                WITH RankedAssignments AS
                (
                    SELECT Id,
                           ROW_NUMBER() OVER
                           (
                               PARTITION BY UserAccountId, HotelId
                               ORDER BY AssignedAtUtc DESC, Id DESC
                           ) AS AssignmentRank
                    FROM HotelStaffAssignments
                    WHERE IsActive = 1
                )
                UPDATE assignment
                SET IsActive = 0
                FROM HotelStaffAssignments AS assignment
                INNER JOIN RankedAssignments AS ranked ON ranked.Id = assignment.Id
                WHERE ranked.AssignmentRank > 1;
                """);

            migrationBuilder.CreateIndex(
                name: "IX_HotelStaffAssignments_UserAccountId_HotelId",
                table: "HotelStaffAssignments",
                columns: new[] { "UserAccountId", "HotelId" },
                unique: true,
                filter: "[IsActive] = 1");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_HotelStaffAssignments_UserAccountId_HotelId",
                table: "HotelStaffAssignments");

            migrationBuilder.CreateIndex(
                name: "IX_HotelStaffAssignments_UserAccountId_HotelId_RoleId",
                table: "HotelStaffAssignments",
                columns: new[] { "UserAccountId", "HotelId", "RoleId" },
                unique: true,
                filter: "[IsActive] = 1");
        }
    }
}

#pragma warning restore CA1861
