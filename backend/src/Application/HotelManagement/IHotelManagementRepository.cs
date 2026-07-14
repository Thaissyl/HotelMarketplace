using HotelMarketplace.Domain.Entities;

namespace HotelMarketplace.Application.HotelManagement;

public interface IHotelManagementRepository
{
    Task AddHotelAsync(HotelProperty hotel, CancellationToken cancellationToken);

    Task<IReadOnlyCollection<HotelProperty>> GetHotelsOwnedByAsync(Guid ownerUserAccountId, CancellationToken cancellationToken);

    Task<HotelProperty?> GetHotelByIdAsync(Guid hotelId, CancellationToken cancellationToken);

    Task<bool> UserOwnsHotelAsync(Guid userAccountId, Guid hotelId, CancellationToken cancellationToken);

    Task AddRoomTypeAsync(RoomType roomType, CancellationToken cancellationToken);

    Task<IReadOnlyCollection<RoomType>> GetRoomTypesAsync(Guid hotelId, CancellationToken cancellationToken);

    Task<RoomType?> GetRoomTypeAsync(Guid hotelId, Guid roomTypeId, CancellationToken cancellationToken);

    Task<bool> RoomTypeHasActiveFutureBookingsAsync(Guid roomTypeId, DateOnly today, CancellationToken cancellationToken);

    Task AddPhysicalRoomAsync(PhysicalRoom physicalRoom, CancellationToken cancellationToken);

    Task<IReadOnlyCollection<PhysicalRoom>> GetPhysicalRoomsAsync(Guid hotelId, Guid? roomTypeId, CancellationToken cancellationToken);

    Task<PhysicalRoom?> GetPhysicalRoomAsync(Guid hotelId, Guid physicalRoomId, CancellationToken cancellationToken);

    Task<bool> RoomNumberExistsAsync(Guid hotelId, string roomNumber, Guid? excludedPhysicalRoomId, CancellationToken cancellationToken);

    Task SaveChangesAsync(CancellationToken cancellationToken);
}
