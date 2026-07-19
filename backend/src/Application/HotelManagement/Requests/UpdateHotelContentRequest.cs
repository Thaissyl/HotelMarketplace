namespace HotelMarketplace.Application.HotelManagement.Requests;

public sealed record UpdateHotelContentRequest(
    IReadOnlyCollection<HotelImageInput> Images,
    IReadOnlyCollection<HotelAmenityInput> Amenities,
    CancellationPolicyInput? CancellationPolicy);

public sealed record HotelImageInput(string ImageUrl, int DisplayOrder);

public sealed record HotelAmenityInput(string Code, string Name, string Type);

public sealed record CancellationPolicyInput(
    string Name,
    int FreeCancellationHours,
    decimal RefundPercentage,
    string? Description);
