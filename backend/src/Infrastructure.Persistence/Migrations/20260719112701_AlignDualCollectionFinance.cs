using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AlignDualCollectionFinance : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "CK_SettlementRecords_TotalAmount",
                table: "SettlementRecords");

            migrationBuilder.RenameColumn(
                name: "TotalAmount",
                table: "SettlementRecords",
                newName: "ExpectedAmount");

            migrationBuilder.AddColumn<string>(
                name: "Reference",
                table: "SettlementRecords",
                type: "nvarchar(128)",
                maxLength: 128,
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<decimal>(
                name: "SettledAmount",
                table: "SettlementRecords",
                type: "decimal(18,2)",
                precision: 18,
                scale: 2,
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "SettlementDateUtc",
                table: "SettlementRecords",
                type: "datetime2(3)",
                precision: 3,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "BookingStatus",
                table: "SettlementItems",
                type: "nvarchar(64)",
                maxLength: 64,
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<decimal>(
                name: "CommissionAmount",
                table: "SettlementItems",
                type: "decimal(18,2)",
                precision: 18,
                scale: 2,
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<decimal>(
                name: "GrossAmount",
                table: "SettlementItems",
                type: "decimal(18,2)",
                precision: 18,
                scale: 2,
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<Guid>(
                name: "PaymentCollectionRecordId",
                table: "SettlementItems",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "PaymentMode",
                table: "SettlementItems",
                type: "nvarchar(64)",
                maxLength: 64,
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<decimal>(
                name: "RefundAmount",
                table: "SettlementItems",
                type: "decimal(18,2)",
                precision: 18,
                scale: 2,
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<DateTime>(
                name: "ReconciledAtUtc",
                table: "PaymentTransactions",
                type: "datetime2(3)",
                precision: 3,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ReconciliationNote",
                table: "PaymentTransactions",
                type: "nvarchar(1000)",
                maxLength: 1000,
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "BalanceAfter",
                table: "PaymentCollectionRecords",
                type: "decimal(18,2)",
                precision: 18,
                scale: 2,
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<decimal>(
                name: "BalanceBefore",
                table: "PaymentCollectionRecords",
                type: "decimal(18,2)",
                precision: 18,
                scale: 2,
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<string>(
                name: "CorrectionNote",
                table: "PaymentCollectionRecords",
                type: "nvarchar(500)",
                maxLength: 500,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Method",
                table: "PaymentCollectionRecords",
                type: "nvarchar(64)",
                maxLength: 64,
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<string>(
                name: "Note",
                table: "PaymentCollectionRecords",
                type: "nvarchar(500)",
                maxLength: 500,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Reference",
                table: "PaymentCollectionRecords",
                type: "nvarchar(128)",
                maxLength: 128,
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<DateTime>(
                name: "VoidedAtUtc",
                table: "PaymentCollectionRecords",
                type: "datetime2(3)",
                precision: 3,
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "BalanceAmount",
                table: "Invoices",
                type: "decimal(18,2)",
                precision: 18,
                scale: 2,
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<DateTime>(
                name: "FinalizedAtUtc",
                table: "Invoices",
                type: "datetime2(3)",
                precision: 3,
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "RefundAmount",
                table: "Invoices",
                type: "decimal(18,2)",
                precision: 18,
                scale: 2,
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<string>(
                name: "Status",
                table: "CommissionRecords",
                type: "nvarchar(64)",
                maxLength: 64,
                nullable: false,
                defaultValue: "");

            migrationBuilder.Sql(
                """
                UPDATE collection
                SET BalanceBefore = collection.Amount,
                    BalanceAfter = 0,
                    Method = N'Cash',
                    Reference = N'LEGACY-COLLECTION-' + REPLACE(CONVERT(nvarchar(36), collection.Id), N'-', N''),
                    Note = COALESCE(collection.Note, N'Migrated hotel-side collection.'),
                    Status = CASE WHEN collection.Status = N'Paid' THEN N'Completed' ELSE N'Exception' END
                FROM PaymentCollectionRecords AS collection;

                UPDATE commission
                SET Status = CASE
                    WHEN booking.PaymentMode = N'PayAtProperty' THEN N'Receivable'
                    ELSE N'Deductible'
                END
                FROM CommissionRecords AS commission
                INNER JOIN Bookings AS booking ON booking.Id = commission.BookingId;

                UPDATE settlement
                SET Reference = CASE
                        WHEN settlement.Status IN (N'Settled', N'Collected')
                            THEN N'LEGACY-SETTLEMENT-' + REPLACE(CONVERT(nvarchar(36), settlement.Id), N'-', N'')
                        ELSE N''
                    END,
                    SettledAmount = CASE
                        WHEN settlement.Status IN (N'Settled', N'Collected') THEN settlement.ExpectedAmount
                        ELSE NULL
                    END,
                    SettlementDateUtc = CASE
                        WHEN settlement.Status IN (N'Settled', N'Collected') THEN settlement.CreatedAtUtc
                        ELSE NULL
                    END
                FROM SettlementRecords AS settlement;

                UPDATE item
                SET BookingStatus = booking.Status,
                    PaymentMode = booking.PaymentMode,
                    GrossAmount = booking.TotalAmount,
                    RefundAmount = COALESCE(refund.ProcessedRefundAmount, 0),
                    CommissionAmount = commission.CommissionAmount,
                    PaymentCollectionRecordId = CASE
                        WHEN booking.PaymentMode = N'PayAtProperty' THEN collection.Id
                        ELSE NULL
                    END
                FROM SettlementItems AS item
                INNER JOIN Bookings AS booking ON booking.Id = item.BookingId
                INNER JOIN CommissionRecords AS commission ON commission.Id = item.CommissionRecordId
                OUTER APPLY (
                    SELECT SUM(refundRecord.ApprovedAmount) AS ProcessedRefundAmount
                    FROM RefundRecords AS refundRecord
                    WHERE refundRecord.BookingId = booking.Id
                        AND refundRecord.Status = N'Processed'
                ) AS refund
                OUTER APPLY (
                    SELECT TOP(1) paymentCollection.Id
                    FROM PaymentCollectionRecords AS paymentCollection
                    WHERE paymentCollection.BookingId = booking.Id
                        AND paymentCollection.Status IN (N'Partial', N'Completed')
                    ORDER BY paymentCollection.CollectedAtUtc DESC
                ) AS collection;

                UPDATE invoice
                SET RefundAmount = COALESCE(refund.ProcessedRefundAmount, 0),
                    BalanceAmount = CASE
                        WHEN invoice.RoomAmount - invoice.PaidAmount + COALESCE(refund.ProcessedRefundAmount, 0) > 0
                            THEN invoice.RoomAmount - invoice.PaidAmount + COALESCE(refund.ProcessedRefundAmount, 0)
                        ELSE 0
                    END,
                    FinalizedAtUtc = CASE
                        WHEN invoice.RoomAmount - invoice.PaidAmount + COALESCE(refund.ProcessedRefundAmount, 0) <= 0
                            THEN invoice.IssuedAtUtc
                        ELSE NULL
                    END,
                    Status = CASE
                        WHEN invoice.RoomAmount - invoice.PaidAmount + COALESCE(refund.ProcessedRefundAmount, 0) <= 0
                            THEN N'Paid'
                        ELSE N'Issued'
                    END
                FROM Invoices AS invoice
                OUTER APPLY (
                    SELECT SUM(refundRecord.ApprovedAmount) AS ProcessedRefundAmount
                    FROM RefundRecords AS refundRecord
                    WHERE refundRecord.BookingId = invoice.BookingId
                        AND refundRecord.Status = N'Processed'
                ) AS refund;

                UPDATE payment
                SET ReconciledAtUtc = CASE
                        WHEN payment.ReconciliationStatus IN (N'Reconciled', N'Exception')
                            THEN COALESCE(payment.PaidAtUtc, payment.CreatedAtUtc)
                        ELSE NULL
                    END,
                    ReconciliationNote = CASE
                        WHEN payment.ReconciliationStatus = N'Exception'
                            THEN N'Migrated reconciliation exception.'
                        ELSE NULL
                    END
                FROM PaymentTransactions AS payment;
                """);

            migrationBuilder.CreateIndex(
                name: "IX_SettlementRecords_Reference",
                table: "SettlementRecords",
                column: "Reference",
                unique: true,
                filter: "[Reference] <> ''");

            migrationBuilder.AddCheckConstraint(
                name: "CK_SettlementRecords_ExpectedAmount",
                table: "SettlementRecords",
                sql: "[ExpectedAmount] >= 0");

            migrationBuilder.AddCheckConstraint(
                name: "CK_SettlementRecords_SettledAmount",
                table: "SettlementRecords",
                sql: "[SettledAmount] IS NULL OR [SettledAmount] >= 0");

            migrationBuilder.CreateIndex(
                name: "IX_SettlementItems_PaymentCollectionRecordId",
                table: "SettlementItems",
                column: "PaymentCollectionRecordId");

            migrationBuilder.CreateIndex(
                name: "IX_PaymentCollectionRecords_Reference",
                table: "PaymentCollectionRecords",
                column: "Reference",
                unique: true);

            migrationBuilder.AddCheckConstraint(
                name: "CK_Invoices_BalanceAmount",
                table: "Invoices",
                sql: "[BalanceAmount] >= 0");

            migrationBuilder.AddCheckConstraint(
                name: "CK_Invoices_RefundAmount",
                table: "Invoices",
                sql: "[RefundAmount] >= 0");

            migrationBuilder.AddForeignKey(
                name: "FK_SettlementItems_PaymentCollectionRecords_PaymentCollectionRecordId",
                table: "SettlementItems",
                column: "PaymentCollectionRecordId",
                principalTable: "PaymentCollectionRecords",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_SettlementItems_PaymentCollectionRecords_PaymentCollectionRecordId",
                table: "SettlementItems");

            migrationBuilder.DropIndex(
                name: "IX_SettlementRecords_Reference",
                table: "SettlementRecords");

            migrationBuilder.DropCheckConstraint(
                name: "CK_SettlementRecords_ExpectedAmount",
                table: "SettlementRecords");

            migrationBuilder.DropCheckConstraint(
                name: "CK_SettlementRecords_SettledAmount",
                table: "SettlementRecords");

            migrationBuilder.DropIndex(
                name: "IX_SettlementItems_PaymentCollectionRecordId",
                table: "SettlementItems");

            migrationBuilder.DropIndex(
                name: "IX_PaymentCollectionRecords_Reference",
                table: "PaymentCollectionRecords");

            migrationBuilder.DropCheckConstraint(
                name: "CK_Invoices_BalanceAmount",
                table: "Invoices");

            migrationBuilder.DropCheckConstraint(
                name: "CK_Invoices_RefundAmount",
                table: "Invoices");

            migrationBuilder.DropColumn(
                name: "Reference",
                table: "SettlementRecords");

            migrationBuilder.DropColumn(
                name: "SettledAmount",
                table: "SettlementRecords");

            migrationBuilder.DropColumn(
                name: "SettlementDateUtc",
                table: "SettlementRecords");

            migrationBuilder.DropColumn(
                name: "BookingStatus",
                table: "SettlementItems");

            migrationBuilder.DropColumn(
                name: "CommissionAmount",
                table: "SettlementItems");

            migrationBuilder.DropColumn(
                name: "GrossAmount",
                table: "SettlementItems");

            migrationBuilder.DropColumn(
                name: "PaymentCollectionRecordId",
                table: "SettlementItems");

            migrationBuilder.DropColumn(
                name: "PaymentMode",
                table: "SettlementItems");

            migrationBuilder.DropColumn(
                name: "RefundAmount",
                table: "SettlementItems");

            migrationBuilder.DropColumn(
                name: "ReconciledAtUtc",
                table: "PaymentTransactions");

            migrationBuilder.DropColumn(
                name: "ReconciliationNote",
                table: "PaymentTransactions");

            migrationBuilder.DropColumn(
                name: "BalanceAfter",
                table: "PaymentCollectionRecords");

            migrationBuilder.DropColumn(
                name: "BalanceBefore",
                table: "PaymentCollectionRecords");

            migrationBuilder.DropColumn(
                name: "CorrectionNote",
                table: "PaymentCollectionRecords");

            migrationBuilder.DropColumn(
                name: "Method",
                table: "PaymentCollectionRecords");

            migrationBuilder.DropColumn(
                name: "Note",
                table: "PaymentCollectionRecords");

            migrationBuilder.DropColumn(
                name: "Reference",
                table: "PaymentCollectionRecords");

            migrationBuilder.DropColumn(
                name: "VoidedAtUtc",
                table: "PaymentCollectionRecords");

            migrationBuilder.DropColumn(
                name: "BalanceAmount",
                table: "Invoices");

            migrationBuilder.DropColumn(
                name: "FinalizedAtUtc",
                table: "Invoices");

            migrationBuilder.DropColumn(
                name: "RefundAmount",
                table: "Invoices");

            migrationBuilder.DropColumn(
                name: "Status",
                table: "CommissionRecords");

            migrationBuilder.RenameColumn(
                name: "ExpectedAmount",
                table: "SettlementRecords",
                newName: "TotalAmount");

            migrationBuilder.AddCheckConstraint(
                name: "CK_SettlementRecords_TotalAmount",
                table: "SettlementRecords",
                sql: "[TotalAmount] >= 0");
        }
    }
}
