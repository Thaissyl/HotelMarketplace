namespace HotelMarketplace.Application.PlatformAdmin.Dtos;

public sealed record AdminUserActivityDto(
    Guid Id,
    Guid ActorUserAccountId,
    string ActorEmail,
    string ActionType,
    string TargetEntityType,
    Guid TargetEntityId,
    string Summary,
    DateTime ActionTimestampUtc);
