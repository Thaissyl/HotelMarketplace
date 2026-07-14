using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.PlatformAdmin.Dtos;

public sealed record AdminHotelDto(
    Guid Id,
    Guid OwnerUserAccountId,
    string Name,
    string City,
    string AddressLine,
    string ContactEmail,
    string ContactPhone,
    HotelApprovalStatus ApprovalStatus,
    PublicationStatus PublicationStatus,
    decimal DefaultCommissionRate,
    DateTime CreatedAtUtc);
