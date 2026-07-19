using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.Security;

public sealed record HotelRoleAccess(Guid HotelId, UserRoleCode Role);
