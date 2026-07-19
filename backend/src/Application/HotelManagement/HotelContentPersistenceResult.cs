using HotelMarketplace.Application.HotelManagement.Dtos;

namespace HotelMarketplace.Application.HotelManagement;

public enum HotelContentPersistenceStatus
{
    Success = 0,
    HotelNotFound = 1,
    LockUnavailable = 2
}

public sealed record HotelContentPersistenceResult(
    HotelContentPersistenceStatus Status,
    HotelContentDto? Content)
{
    public static HotelContentPersistenceResult Success(HotelContentDto content) =>
        new(HotelContentPersistenceStatus.Success, content);

    public static HotelContentPersistenceResult Failure(HotelContentPersistenceStatus status) =>
        new(status, null);
}
