using FluentAssertions;
using HotelMarketplace.Domain.Entities;
using HotelMarketplace.Domain.Enums;
using HotelMarketplace.SharedKernel.Exceptions;
using Xunit;

namespace HotelMarketplace.Domain.UnitTests;

public sealed class FinanceInvariantTests
{
    [Fact]
    public void PaymentCollectionCannotExceedOutstandingBalance()
    {
        Action action = () => _ = new PaymentCollectionRecord(
            Guid.NewGuid(),
            Guid.NewGuid(),
            Guid.NewGuid(),
            Guid.NewGuid(),
            amount: 101m,
            balanceBefore: 100m,
            PaymentCollectionMethod.Cash,
            "RECEIPT-001",
            DateTime.UtcNow);

        action.Should().Throw<DomainException>()
            .Where(exception => exception.Code == "PaymentCollectionRecord.AmountExceedsBalance");
    }

    [Fact]
    public void InvoiceCannotFinalizeWithOutstandingBalance()
    {
        Action action = () => _ = new Invoice(
            Guid.NewGuid(),
            Guid.NewGuid(),
            Guid.NewGuid(),
            "INV-001",
            roomAmount: 100m,
            paidAmount: 90m,
            refundAmount: 0m,
            DateTime.UtcNow);

        action.Should().Throw<DomainException>()
            .Where(exception => exception.Code == "Invoice.OutstandingBalance");
    }

    [Fact]
    public void SettlementCannotFinalizeWithAmountDifferentFromSnapshot()
    {
        SettlementRecord settlement = new(
            Guid.NewGuid(),
            Guid.NewGuid(),
            SettlementType.HotelPayable,
            expectedAmount: 100m,
            adminNote: null);

        Action action = () => settlement.MarkSettled(
            settledAmount: 99m,
            DateTime.UtcNow,
            "BANK-001",
            adminNote: null);

        action.Should().Throw<DomainException>()
            .Where(exception => exception.Code == "SettlementRecord.AmountMismatch");
    }

    [Fact]
    public void CollectedCommissionSettlementCannotBecomeException()
    {
        SettlementRecord settlement = new(
            Guid.NewGuid(),
            Guid.NewGuid(),
            SettlementType.CommissionCollection,
            expectedAmount: 25m,
            adminNote: null);
        settlement.MarkSettled(25m, DateTime.UtcNow, "CASH-001", adminNote: null);

        Action action = () => settlement.MarkException("Late correction");

        action.Should().Throw<DomainException>()
            .Where(exception => exception.Code == "SettlementRecord.FinalizedCannotBecomeException");
    }
}
