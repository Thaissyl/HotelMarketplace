using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.HotelManagement.Dtos;

public sealed record HotelDto(
    Guid Id,
    Guid OwnerUserAccountId,
    string Name,
    string City,
    string AddressLine,
    string ContactEmail,
    string ContactPhone,
    string? Description,
    HotelApprovalStatus ApprovalStatus,
    PublicationStatus PublicationStatus,
    bool RequiresRoomInspection,
    DateTime CreatedAtUtc);
