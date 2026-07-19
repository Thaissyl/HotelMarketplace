using System;
using Microsoft.EntityFrameworkCore.Migrations;

#pragma warning disable CA1861

#nullable disable

namespace Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddProtectedAnonymousWalkInCustomer : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "IsSystemAccount",
                table: "UserAccounts",
                type: "bit",
                nullable: false,
                defaultValue: false);

            migrationBuilder.InsertData(
                table: "UserAccounts",
                columns: new[] { "Id", "CreatedAtUtc", "Email", "FullName", "IsSystemAccount", "PasswordHash", "PhoneNumber", "Status" },
                values: new object[] { new Guid("22222222-2222-2222-2222-222222222001"), new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), "anonymous-walk-in@system.local", "Anonymous Walk-in Customer", true, "LOGIN-DISABLED", null, "Active" });

            migrationBuilder.InsertData(
                table: "UserAccountRoles",
                columns: new[] { "Id", "AssignedAtUtc", "IsActive", "RoleId", "UserAccountId" },
                values: new object[] { new Guid("22222222-2222-2222-2222-222222222002"), new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), true, new Guid("11111111-1111-1111-1111-111111111001"), new Guid("22222222-2222-2222-2222-222222222001") });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DeleteData(
                table: "UserAccountRoles",
                keyColumn: "Id",
                keyValue: new Guid("22222222-2222-2222-2222-222222222002"));

            migrationBuilder.DeleteData(
                table: "UserAccounts",
                keyColumn: "Id",
                keyValue: new Guid("22222222-2222-2222-2222-222222222001"));

            migrationBuilder.DropColumn(
                name: "IsSystemAccount",
                table: "UserAccounts");
        }
    }
}

#pragma warning restore CA1861
