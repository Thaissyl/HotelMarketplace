using HotelMarketplace.Domain.Common;
using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Domain.Entities;

public sealed class SettlementRecord : Entity, IHotelScopedEntity
{
    private SettlementRecord()
    {
        SettlementType = string.Empty;
    }

    public SettlementRecord(Guid id, Guid hotelId, string settlementType, decimal totalAmount)
        : base(id)
    {
        Guard.NotEmpty(hotelId, nameof(HotelId));
        Guard.NonNegative(totalAmount, nameof(TotalAmount));
        HotelId = hotelId;
        SettlementType = Guard.NotBlank(settlementType, nameof(SettlementType), 64);
        TotalAmount = totalAmount;
        Status = SettlementStatus.Pending;
        CreatedAtUtc = DateTime.UtcNow;
    }

    public Guid HotelId { get; private set; }

    public string SettlementType { get; private set; }

    public decimal TotalAmount { get; private set; }

    public SettlementStatus Status { get; private set; }

    public string? AdminNote { get; private set; }

    public DateTime CreatedAtUtc { get; private set; }

    public void MarkSettled(string? adminNote)
    {
        if (Status != SettlementStatus.Pending)
        {
            throw new SharedKernel.Exceptions.DomainException("SettlementRecord.InvalidStatusForSettlement", "Only pending settlements can be marked as settled.");
        }

        Status = SettlementStatus.Settled;
        AdminNote = Guard.Optional(adminNote, nameof(AdminNote), 1000);
    }

    public void MarkException(string adminNote)
    {
        if (Status == SettlementStatus.Settled)
        {
            throw new SharedKernel.Exceptions.DomainException("SettlementRecord.SettledCannotBecomeException", "Settled records cannot be changed to exception.");
        }

        Status = SettlementStatus.Exception;
        AdminNote = Guard.NotBlank(adminNote, nameof(AdminNote), 1000);
    }
}
