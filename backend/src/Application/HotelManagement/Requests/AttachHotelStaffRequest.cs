using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.HotelManagement.Requests;

public sealed record AttachHotelStaffRequest(
    string Email,
    UserRoleCode Role);
