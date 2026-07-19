using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class NormalizeDemoPaymentProvider : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                UPDATE [PaymentTransactions]
                SET [Provider] = N'DEMO'
                WHERE [Provider] IN (N'payOS', N'Simulated');
                """);

            migrationBuilder.DropColumn(
                name: "CheckoutUrl",
                table: "PaymentTransactions");

            migrationBuilder.DropColumn(
                name: "GatewayPaymentLinkId",
                table: "PaymentTransactions");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
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
        }
    }
}
