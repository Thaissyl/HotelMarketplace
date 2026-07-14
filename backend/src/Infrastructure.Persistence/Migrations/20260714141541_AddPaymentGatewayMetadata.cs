using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddPaymentGatewayMetadata : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "CheckoutUrl",
                table: "PaymentTransactions",
                type: "nvarchar(1000)",
                maxLength: 1000,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "GatewayPaymentLinkId",
                table: "PaymentTransactions",
                type: "nvarchar(128)",
                maxLength: 128,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "GatewayTransactionReference",
                table: "PaymentTransactions",
                type: "nvarchar(128)",
                maxLength: 128,
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "PaidAtUtc",
                table: "PaymentTransactions",
                type: "datetime2(3)",
                precision: 3,
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_PaymentTransactions_GatewayTransactionReference",
                table: "PaymentTransactions",
                column: "GatewayTransactionReference",
                unique: true,
                filter: "[GatewayTransactionReference] IS NOT NULL");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_PaymentTransactions_GatewayTransactionReference",
                table: "PaymentTransactions");

            migrationBuilder.DropColumn(
                name: "CheckoutUrl",
                table: "PaymentTransactions");

            migrationBuilder.DropColumn(
                name: "GatewayPaymentLinkId",
                table: "PaymentTransactions");

            migrationBuilder.DropColumn(
                name: "GatewayTransactionReference",
                table: "PaymentTransactions");

            migrationBuilder.DropColumn(
                name: "PaidAtUtc",
                table: "PaymentTransactions");
        }
    }
}
