using HotelMarketplace.Domain.Common;
using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Domain.Entities;

public sealed class NotificationRecord : Entity
{
    private NotificationRecord()
    {
        EventType = string.Empty;
        RelatedEntityType = string.Empty;
        Message = string.Empty;
    }

    public NotificationRecord(Guid id, Guid? recipientUserAccountId, string eventType, string relatedEntityType, Guid relatedEntityId, string message, Guid? hotelId = null)
        : base(id)
    {
        Guard.NotEmpty(relatedEntityId, nameof(RelatedEntityId));
        RecipientUserAccountId = recipientUserAccountId;
        HotelId = hotelId;
        EventType = Guard.NotBlank(eventType, nameof(EventType), 128);
        RelatedEntityType = Guard.NotBlank(relatedEntityType, nameof(RelatedEntityType), 128);
        RelatedEntityId = relatedEntityId;
        Message = Guard.NotBlank(message, nameof(Message), 1000);
        Status = NotificationStatus.Pending;
        CreatedAtUtc = DateTime.UtcNow;
    }

    public Guid? HotelId { get; private set; }

    public Guid? RecipientUserAccountId { get; private set; }

    public string EventType { get; private set; }

    public string RelatedEntityType { get; private set; }

    public Guid RelatedEntityId { get; private set; }

    public string Message { get; private set; }

    public NotificationStatus Status { get; private set; }

    public DateTime CreatedAtUtc { get; private set; }
}
