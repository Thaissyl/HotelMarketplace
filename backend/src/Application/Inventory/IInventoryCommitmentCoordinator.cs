namespace HotelMarketplace.Application.Inventory;

public interface IInventoryCommitmentCoordinator
{
    Task<InventoryCommitmentEvaluation> AcquireAndEvaluateAsync(
        Guid hotelId,
        Guid roomTypeId,
        DateOnly checkInDate,
        DateOnly checkOutDate,
        int requestedRoomCount,
        DateTime utcNow,
        Guid? ignoredBookingId,
        CancellationToken cancellationToken);

    Task<bool> AcquireRoomTypeLockAsync(
        Guid hotelId,
        Guid roomTypeId,
        CancellationToken cancellationToken);

    Task<bool> AcquireRoomTypeLocksAsync(
        IEnumerable<InventoryRoomTypeKey> roomTypes,
        CancellationToken cancellationToken);
}

public sealed record InventoryRoomTypeKey(Guid HotelId, Guid RoomTypeId);

public sealed record InventoryCommitmentEvaluation(
    InventoryCommitmentStatus Status,
    int AvailableRoomCount)
{
    public static InventoryCommitmentEvaluation Available(int availableRoomCount) =>
        new(InventoryCommitmentStatus.Available, availableRoomCount);

    public static InventoryCommitmentEvaluation Insufficient(int availableRoomCount) =>
        new(InventoryCommitmentStatus.InsufficientAvailability, availableRoomCount);

    public static InventoryCommitmentEvaluation LockUnavailable() =>
        new(InventoryCommitmentStatus.LockUnavailable, 0);
}

public enum InventoryCommitmentStatus
{
    Available = 1,
    InsufficientAvailability = 2,
    LockUnavailable = 3
}
