namespace HotelMarketplace.Application.HotelManagement.Dtos;

public sealed record HotelContentDto(
    IReadOnlyCollection<HotelImageManagementDto> Images,
    IReadOnlyCollection<HotelAmenityManagementDto> Amenities,
    CancellationPolicyManagementDto? CancellationPolicy);

public sealed record HotelImageManagementDto(Guid Id, string ImageUrl, int DisplayOrder);

public sealed record HotelAmenityManagementDto(Guid Id, string Code, string Name, string Type);

public sealed record CancellationPolicyManagementDto(
    Guid Id,
    string Name,
    int FreeCancellationHours,
    decimal RefundPercentage,
    string? Description);
