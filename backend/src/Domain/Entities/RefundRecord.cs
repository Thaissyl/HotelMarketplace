using HotelMarketplace.Domain.Common;
using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Domain.Entities;

public sealed class RefundRecord : Entity, IHotelScopedEntity
{
    private RefundRecord()
    {
        Reason = string.Empty;
    }

    public RefundRecord(Guid id, Guid hotelId, Guid bookingId, decimal requestedAmount, string reason)
        : base(id)
    {
        Guard.NotEmpty(hotelId, nameof(HotelId));
        Guard.NotEmpty(bookingId, nameof(BookingId));
        Guard.NonNegative(requestedAmount, nameof(RequestedAmount));
        HotelId = hotelId;
        BookingId = bookingId;
        RequestedAmount = requestedAmount;
        ApprovedAmount = 0m;
        Reason = Guard.NotBlank(reason, nameof(Reason), 500);
        Status = RefundStatus.PendingReview;
        CreatedAtUtc = DateTime.UtcNow;
    }

    public Guid HotelId { get; private set; }

    public Guid BookingId { get; private set; }

    public decimal RequestedAmount { get; private set; }

    public decimal ApprovedAmount { get; private set; }

    public string Reason { get; private set; }

    public RefundStatus Status { get; private set; }

    public DateTime CreatedAtUtc { get; private set; }

    public void Approve(decimal approvedAmount)
    {
        if (Status != RefundStatus.PendingReview)
        {
            throw new SharedKernel.Exceptions.DomainException("RefundRecord.InvalidStatusForApproval", "Only pending refund requests can be approved.");
        }

        Guard.NonNegative(approvedAmount, nameof(ApprovedAmount));

        if (approvedAmount > RequestedAmount)
        {
            throw new SharedKernel.Exceptions.DomainException("RefundRecord.ApprovedAmountTooLarge", "Approved refund amount cannot exceed requested amount.");
        }

        ApprovedAmount = approvedAmount;
        Status = RefundStatus.Approved;
    }

    public void Reject()
    {
        if (Status != RefundStatus.PendingReview)
        {
            throw new SharedKernel.Exceptions.DomainException("RefundRecord.InvalidStatusForRejection", "Only pending refund requests can be rejected.");
        }

        ApprovedAmount = 0m;
        Status = RefundStatus.Rejected;
    }

    public void MarkProcessed()
    {
        if (Status != RefundStatus.Approved)
        {
            throw new SharedKernel.Exceptions.DomainException("RefundRecord.InvalidStatusForProcessing", "Only approved refund requests can be marked as processed.");
        }

        Status = RefundStatus.Processed;
    }

    public void MarkFailed()
    {
        if (Status != RefundStatus.Approved)
        {
            throw new SharedKernel.Exceptions.DomainException("RefundRecord.InvalidStatusForFailure", "Only approved refund requests can be marked as failed.");
        }

        Status = RefundStatus.Failed;
    }
}
