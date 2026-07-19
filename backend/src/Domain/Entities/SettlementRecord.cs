using HotelMarketplace.Domain.Common;
using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Domain.Entities;

public sealed class SettlementRecord : Entity, IHotelScopedEntity
{
    private SettlementRecord()
    {
        Reference = string.Empty;
    }

    public SettlementRecord(Guid id, Guid hotelId, SettlementType settlementType, decimal expectedAmount, string? adminNote)
        : base(id)
    {
        Guard.NotEmpty(hotelId, nameof(HotelId));
        Guard.NonNegative(expectedAmount, nameof(ExpectedAmount));
        HotelId = hotelId;
        Reference = string.Empty;
        SettlementType = settlementType;
        ExpectedAmount = expectedAmount;
        AdminNote = Guard.Optional(adminNote, nameof(AdminNote), 1000);
        Status = SettlementStatus.Pending;
        CreatedAtUtc = DateTime.UtcNow;
    }

    public Guid HotelId { get; private set; }

    public SettlementType SettlementType { get; private set; }

    public decimal ExpectedAmount { get; private set; }

    public decimal? SettledAmount { get; private set; }

    public SettlementStatus Status { get; private set; }

    public string? AdminNote { get; private set; }

    public DateTime CreatedAtUtc { get; private set; }

    public DateTime? SettlementDateUtc { get; private set; }

    public string Reference { get; private set; }

    public void MarkSettled(decimal settledAmount, DateTime settlementDateUtc, string reference, string? adminNote)
    {
        if (Status != SettlementStatus.Pending)
        {
            throw new SharedKernel.Exceptions.DomainException("SettlementRecord.InvalidStatusForSettlement", "Only pending settlements can be marked as settled.");
        }

        if (settledAmount != ExpectedAmount)
        {
            throw new SharedKernel.Exceptions.DomainException(
                "SettlementRecord.AmountMismatch",
                "Settled amount must match the immutable expected amount.");
        }

        SettledAmount = settledAmount;
        SettlementDateUtc = EnsureUtc(settlementDateUtc);
        Reference = Guard.NotBlank(reference, nameof(Reference), 128).ToUpperInvariant();
        Status = SettlementType == Domain.Enums.SettlementType.HotelPayable
            ? SettlementStatus.Settled
            : SettlementStatus.Collected;
        AdminNote = Guard.Optional(adminNote, nameof(AdminNote), 1000);
    }

    public void MarkException(string adminNote)
    {
        if (Status is SettlementStatus.Settled or SettlementStatus.Collected)
        {
            throw new SharedKernel.Exceptions.DomainException("SettlementRecord.FinalizedCannotBecomeException", "Finalized settlement records cannot be changed to exception.");
        }

        Status = SettlementStatus.Exception;
        AdminNote = Guard.NotBlank(adminNote, nameof(AdminNote), 1000);
    }

    private static DateTime EnsureUtc(DateTime value)
    {
        if (value.Kind == DateTimeKind.Local)
        {
            throw new SharedKernel.Exceptions.DomainException(
                "SettlementRecord.InvalidUtcTimestamp",
                "Settlement date must be expressed in UTC.");
        }

        return DateTime.SpecifyKind(value, DateTimeKind.Utc);
    }
}
