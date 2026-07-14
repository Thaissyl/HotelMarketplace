using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814, CA1861 // Generated migration data.

namespace Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class SeedUserRoles : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.InsertData(
                table: "UserRoles",
                columns: new[] { "Id", "Code", "Name", "Scope" },
                values: new object[,]
                {
                    { new Guid("11111111-1111-1111-1111-111111111001"), "CUSTOMER", "Customer", "Customer" },
                    { new Guid("11111111-1111-1111-1111-111111111002"), "PROPERTYOWNER", "Property Owner", "Hotel" },
                    { new Guid("11111111-1111-1111-1111-111111111003"), "HOTELMANAGER", "Hotel Manager", "Hotel" },
                    { new Guid("11111111-1111-1111-1111-111111111004"), "RECEPTIONIST", "Receptionist", "Hotel" },
                    { new Guid("11111111-1111-1111-1111-111111111005"), "HOUSEKEEPINGSTAFF", "Housekeeping Staff", "Hotel" },
                    { new Guid("11111111-1111-1111-1111-111111111006"), "MAINTENANCESTAFF", "Maintenance Staff", "Hotel" },
                    { new Guid("11111111-1111-1111-1111-111111111007"), "PLATFORMADMINISTRATOR", "Platform Administrator", "Platform" }
                });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DeleteData(
                table: "UserRoles",
                keyColumn: "Id",
                keyValue: new Guid("11111111-1111-1111-1111-111111111001"));

            migrationBuilder.DeleteData(
                table: "UserRoles",
                keyColumn: "Id",
                keyValue: new Guid("11111111-1111-1111-1111-111111111002"));

            migrationBuilder.DeleteData(
                table: "UserRoles",
                keyColumn: "Id",
                keyValue: new Guid("11111111-1111-1111-1111-111111111003"));

            migrationBuilder.DeleteData(
                table: "UserRoles",
                keyColumn: "Id",
                keyValue: new Guid("11111111-1111-1111-1111-111111111004"));

            migrationBuilder.DeleteData(
                table: "UserRoles",
                keyColumn: "Id",
                keyValue: new Guid("11111111-1111-1111-1111-111111111005"));

            migrationBuilder.DeleteData(
                table: "UserRoles",
                keyColumn: "Id",
                keyValue: new Guid("11111111-1111-1111-1111-111111111006"));

            migrationBuilder.DeleteData(
                table: "UserRoles",
                keyColumn: "Id",
                keyValue: new Guid("11111111-1111-1111-1111-111111111007"));
        }
    }
}
