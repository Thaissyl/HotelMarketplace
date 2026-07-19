using HotelMarketplace.Domain.Common;
using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Domain.Entities;

public sealed class PaymentCollectionRecord : Entity, IHotelScopedEntity
{
    private PaymentCollectionRecord()
    {
        Reference = string.Empty;
    }

    public PaymentCollectionRecord(
        Guid id,
        Guid hotelId,
        Guid bookingId,
        Guid collectedByUserAccountId,
        decimal amount,
        decimal balanceBefore,
        PaymentCollectionMethod method,
        string reference,
        DateTime collectedAtUtc,
        string? note = null)
        : base(id)
    {
        Guard.NotEmpty(hotelId, nameof(HotelId));
        Guard.NotEmpty(bookingId, nameof(BookingId));
        Guard.NotEmpty(collectedByUserAccountId, nameof(CollectedByUserAccountId));
        if (amount <= 0)
        {
            throw new SharedKernel.Exceptions.DomainException(
                "PaymentCollectionRecord.InvalidAmount",
                "Collection amount must be greater than zero.");
        }

        Guard.NonNegative(balanceBefore, nameof(BalanceBefore));
        if (amount > balanceBefore)
        {
            throw new SharedKernel.Exceptions.DomainException(
                "PaymentCollectionRecord.AmountExceedsBalance",
                "Collection amount cannot exceed the outstanding balance.");
        }

        HotelId = hotelId;
        BookingId = bookingId;
        CollectedByUserAccountId = collectedByUserAccountId;
        Amount = amount;
        BalanceBefore = balanceBefore;
        BalanceAfter = balanceBefore - amount;
        Method = method;
        Reference = Guard.NotBlank(reference, nameof(Reference), 128).ToUpperInvariant();
        Note = Guard.Optional(note, nameof(Note), 500);
        Status = BalanceAfter == 0
            ? PaymentCollectionStatus.Completed
            : PaymentCollectionStatus.Partial;
        CollectedAtUtc = EnsureUtc(collectedAtUtc);
    }

    public Guid HotelId { get; private set; }

    public Guid BookingId { get; private set; }

    public Guid CollectedByUserAccountId { get; private set; }

    public decimal Amount { get; private set; }

    public decimal BalanceBefore { get; private set; }

    public decimal BalanceAfter { get; private set; }

    public PaymentCollectionMethod Method { get; private set; }

    public string Reference { get; private set; }

    public string? Note { get; private set; }

    public PaymentCollectionStatus Status { get; private set; }

    public DateTime CollectedAtUtc { get; private set; }

    public DateTime? VoidedAtUtc { get; private set; }

    public string? CorrectionNote { get; private set; }

    public void Void(string correctionNote, DateTime voidedAtUtc)
    {
        if (Status == PaymentCollectionStatus.Voided)
        {
            return;
        }

        Status = PaymentCollectionStatus.Voided;
        CorrectionNote = Guard.NotBlank(correctionNote, nameof(CorrectionNote), 500);
        VoidedAtUtc = EnsureUtc(voidedAtUtc);
    }

    public void MarkException(string correctionNote)
    {
        if (Status == PaymentCollectionStatus.Voided)
        {
            throw new SharedKernel.Exceptions.DomainException(
                "PaymentCollectionRecord.VoidedCannotBecomeException",
                "A voided collection cannot become an exception.");
        }

        Status = PaymentCollectionStatus.Exception;
        CorrectionNote = Guard.NotBlank(correctionNote, nameof(CorrectionNote), 500);
    }

    private static DateTime EnsureUtc(DateTime value)
    {
        if (value.Kind == DateTimeKind.Local)
        {
            throw new SharedKernel.Exceptions.DomainException(
                "PaymentCollectionRecord.InvalidUtcTimestamp",
                "Collection time must be expressed in UTC.");
        }

        return DateTime.SpecifyKind(value, DateTimeKind.Utc);
    }
}
