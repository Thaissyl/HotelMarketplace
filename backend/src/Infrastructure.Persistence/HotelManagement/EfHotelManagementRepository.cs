using HotelMarketplace.Application.HotelManagement;
using HotelMarketplace.Domain.Entities;
using HotelMarketplace.Domain.Enums;
using Microsoft.EntityFrameworkCore;

namespace HotelMarketplace.Infrastructure.Persistence.HotelManagement;

internal sealed class EfHotelManagementRepository : IHotelManagementRepository
{
    private readonly HotelMarketplaceDbContext _dbContext;

    public EfHotelManagementRepository(HotelMarketplaceDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    public async Task AddHotelAsync(HotelProperty hotel, CancellationToken cancellationToken)
    {
        await _dbContext.HotelProperties.AddAsync(hotel, cancellationToken);
        await _dbContext.SaveChangesAsync(cancellationToken);
    }

    public async Task<IReadOnlyCollection<HotelProperty>> GetHotelsOwnedByAsync(Guid ownerUserAccountId, CancellationToken cancellationToken)
    {
        return await _dbContext.HotelProperties
            .AsNoTracking()
            .Where(hotel => hotel.OwnerUserAccountId == ownerUserAccountId)
            .OrderByDescending(hotel => hotel.CreatedAtUtc)
            .ToArrayAsync(cancellationToken);
    }

    public Task<HotelProperty?> GetHotelByIdAsync(Guid hotelId, CancellationToken cancellationToken)
    {
        return _dbContext.HotelProperties
            .FirstOrDefaultAsync(hotel => hotel.Id == hotelId, cancellationToken);
    }

    public Task<bool> UserOwnsHotelAsync(Guid userAccountId, Guid hotelId, CancellationToken cancellationToken)
    {
        return _dbContext.HotelProperties
            .AnyAsync(hotel => hotel.Id == hotelId && hotel.OwnerUserAccountId == userAccountId, cancellationToken);
    }

    public async Task AddRoomTypeAsync(RoomType roomType, CancellationToken cancellationToken)
    {
        await _dbContext.RoomTypes.AddAsync(roomType, cancellationToken);
        await _dbContext.SaveChangesAsync(cancellationToken);
    }

    public async Task<IReadOnlyCollection<RoomType>> GetRoomTypesAsync(Guid hotelId, CancellationToken cancellationToken)
    {
        return await _dbContext.RoomTypes
            .AsNoTracking()
            .Where(roomType => roomType.HotelId == hotelId)
            .OrderBy(roomType => roomType.Name)
            .ToArrayAsync(cancellationToken);
    }

    public Task<RoomType?> GetRoomTypeAsync(Guid hotelId, Guid roomTypeId, CancellationToken cancellationToken)
    {
        return _dbContext.RoomTypes
            .FirstOrDefaultAsync(roomType => roomType.HotelId == hotelId && roomType.Id == roomTypeId, cancellationToken);
    }

    public Task<bool> RoomTypeHasActiveFutureBookingsAsync(Guid roomTypeId, DateOnly today, CancellationToken cancellationToken)
    {
        BookingStatus[] activeStatuses =
        {
            BookingStatus.PendingPayment,
            BookingStatus.Confirmed,
            BookingStatus.CheckedIn
        };

        return _dbContext.BookingRooms
            .AsNoTracking()
            .Where(bookingRoom => bookingRoom.RoomTypeId == roomTypeId)
            .Join(
                _dbContext.Bookings.AsNoTracking(),
                bookingRoom => bookingRoom.BookingId,
                booking => booking.Id,
                (_, booking) => booking)
            .AnyAsync(
                booking => booking.CheckOutDate > today && activeStatuses.Contains(booking.Status),
                cancellationToken);
    }

    public async Task AddPhysicalRoomAsync(PhysicalRoom physicalRoom, CancellationToken cancellationToken)
    {
        await _dbContext.PhysicalRooms.AddAsync(physicalRoom, cancellationToken);
        await _dbContext.SaveChangesAsync(cancellationToken);
    }

    public async Task<IReadOnlyCollection<PhysicalRoom>> GetPhysicalRoomsAsync(Guid hotelId, Guid? roomTypeId, CancellationToken cancellationToken)
    {
        IQueryable<PhysicalRoom> query = _dbContext.PhysicalRooms
            .AsNoTracking()
            .Where(room => room.HotelId == hotelId);

        if (roomTypeId.HasValue)
        {
            query = query.Where(room => room.RoomTypeId == roomTypeId.Value);
        }

        return await query
            .OrderBy(room => room.RoomNumber)
            .ToArrayAsync(cancellationToken);
    }

    public Task<PhysicalRoom?> GetPhysicalRoomAsync(Guid hotelId, Guid physicalRoomId, CancellationToken cancellationToken)
    {
        return _dbContext.PhysicalRooms
            .FirstOrDefaultAsync(room => room.HotelId == hotelId && room.Id == physicalRoomId, cancellationToken);
    }

    public Task<bool> RoomNumberExistsAsync(Guid hotelId, string roomNumber, Guid? excludedPhysicalRoomId, CancellationToken cancellationToken)
    {
        string normalizedRoomNumber = roomNumber.Trim();

        IQueryable<PhysicalRoom> query = _dbContext.PhysicalRooms
            .AsNoTracking()
            .Where(room => room.HotelId == hotelId && room.RoomNumber == normalizedRoomNumber);

        if (excludedPhysicalRoomId.HasValue)
        {
            query = query.Where(room => room.Id != excludedPhysicalRoomId.Value);
        }

        return query.AnyAsync(cancellationToken);
    }

    public Task SaveChangesAsync(CancellationToken cancellationToken)
    {
        return _dbContext.SaveChangesAsync(cancellationToken);
    }
}
