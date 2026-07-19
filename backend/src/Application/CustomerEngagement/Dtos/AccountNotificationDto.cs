namespace HotelMarketplace.Application.CustomerEngagement.Dtos;

public sealed record AccountNotificationDto(
    Guid Id,
    string EventType,
    string RelatedEntityType,
    Guid RelatedEntityId,
    string Message,
    Guid? HotelId,
    DateTime CreatedAtUtc,
    DateTime? ReadAtUtc);
