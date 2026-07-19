namespace HotelMarketplace.Application.Marketplace.Dtos;

public sealed record HotelImageDto(Guid Id, string ImageUrl, int DisplayOrder);

public sealed record HotelAmenityDto(Guid Id, string Code, string Name, string Type);

public sealed record CancellationPolicyDto(
    Guid Id,
    string Name,
    int FreeCancellationHours,
    decimal RefundPercentage,
    string? Description);
