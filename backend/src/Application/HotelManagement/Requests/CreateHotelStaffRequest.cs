using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.HotelManagement.Requests;

public sealed record CreateHotelStaffRequest(
    string Email,
    string Password,
    string FullName,
    string PhoneNumber,
    UserRoleCode Role);
