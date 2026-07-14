using HotelMarketplace.Domain.Common;

namespace HotelMarketplace.Domain.Entities;

public sealed class AuditRecord : Entity
{
    private AuditRecord()
    {
        ActionType = string.Empty;
        TargetEntityType = string.Empty;
        Summary = string.Empty;
    }

    public AuditRecord(Guid id, Guid actorUserAccountId, string actionType, string targetEntityType, Guid targetEntityId, string summary, Guid? hotelId = null)
        : base(id)
    {
        Guard.NotEmpty(actorUserAccountId, nameof(ActorUserAccountId));
        Guard.NotEmpty(targetEntityId, nameof(TargetEntityId));
        ActorUserAccountId = actorUserAccountId;
        HotelId = hotelId;
        ActionType = Guard.NotBlank(actionType, nameof(ActionType), 128);
        TargetEntityType = Guard.NotBlank(targetEntityType, nameof(TargetEntityType), 128);
        TargetEntityId = targetEntityId;
        Summary = Guard.NotBlank(summary, nameof(Summary), 1000);
        ActionTimestampUtc = DateTime.UtcNow;
    }

    public Guid? HotelId { get; private set; }

    public Guid ActorUserAccountId { get; private set; }

    public string ActionType { get; private set; }

    public string TargetEntityType { get; private set; }

    public Guid TargetEntityId { get; private set; }

    public string Summary { get; private set; }

    public DateTime ActionTimestampUtc { get; private set; }
}
