using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddDurableCustomerEngagement : Migration
    {
        private static readonly string[] NotificationReadIndexColumns =
            { "RecipientUserAccountId", "ReadAtUtc", "CreatedAtUtc" };
        private static readonly string[] SavedHotelCreatedIndexColumns =
            { "UserAccountId", "CreatedAtUtc" };
        private static readonly string[] SavedHotelUniqueIndexColumns =
            { "UserAccountId", "HotelId" };

        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_NotificationRecords_RecipientUserAccountId",
                table: "NotificationRecords");

            migrationBuilder.AddColumn<DateTime>(
                name: "ReadAtUtc",
                table: "NotificationRecords",
                type: "datetime2(3)",
                precision: 3,
                nullable: true);

            migrationBuilder.CreateTable(
                name: "SavedHotels",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UserAccountId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    HotelId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SavedHotels", x => x.Id);
                    table.ForeignKey(
                        name: "FK_SavedHotels_HotelProperties_HotelId",
                        column: x => x.HotelId,
                        principalTable: "HotelProperties",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_SavedHotels_UserAccounts_UserAccountId",
                        column: x => x.UserAccountId,
                        principalTable: "UserAccounts",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_NotificationRecords_RecipientUserAccountId_ReadAtUtc_CreatedAtUtc",
                table: "NotificationRecords",
                columns: NotificationReadIndexColumns);

            migrationBuilder.CreateIndex(
                name: "IX_SavedHotels_HotelId",
                table: "SavedHotels",
                column: "HotelId");

            migrationBuilder.CreateIndex(
                name: "IX_SavedHotels_UserAccountId_CreatedAtUtc",
                table: "SavedHotels",
                columns: SavedHotelCreatedIndexColumns);

            migrationBuilder.CreateIndex(
                name: "IX_SavedHotels_UserAccountId_HotelId",
                table: "SavedHotels",
                columns: SavedHotelUniqueIndexColumns,
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "SavedHotels");

            migrationBuilder.DropIndex(
                name: "IX_NotificationRecords_RecipientUserAccountId_ReadAtUtc_CreatedAtUtc",
                table: "NotificationRecords");

            migrationBuilder.DropColumn(
                name: "ReadAtUtc",
                table: "NotificationRecords");

            migrationBuilder.CreateIndex(
                name: "IX_NotificationRecords_RecipientUserAccountId",
                table: "NotificationRecords",
                column: "RecipientUserAccountId");
        }
    }
}
