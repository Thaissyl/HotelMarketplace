using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.HotelManagement.Dtos;

public sealed record HotelStaffMemberDto(
    Guid UserAccountId,
    Guid AssignmentId,
    Guid HotelId,
    string Email,
    string FullName,
    string? PhoneNumber,
    UserRoleCode Role,
    AccountStatus Status,
    bool IsAssignmentActive,
    DateTime AssignedAtUtc);
