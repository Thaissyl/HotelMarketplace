using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.HotelManagement.Requests;

public sealed record UpdateHotelStaffAssignmentRequest(
    UserRoleCode? Role,
    bool? IsActive);
