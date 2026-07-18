using System.Data;
using HotelMarketplace.Application.HotelManagement;
using HotelMarketplace.Application.HotelManagement.Dtos;
using HotelMarketplace.Domain.Entities;
using HotelMarketplace.Domain.Enums;
using HotelMarketplace.Infrastructure.Persistence.Common;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;

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

    public async Task<IReadOnlyCollection<HotelProperty>> GetHotelsByIdsAsync(
        IReadOnlyCollection<Guid> hotelIds,
        CancellationToken cancellationToken)
    {
        if (hotelIds.Count == 0)
        {
            return Array.Empty<HotelProperty>();
        }

        return await _dbContext.HotelProperties
            .IgnoreQueryFilters()
            .AsNoTracking()
            .Where(hotel => hotelIds.Contains(hotel.Id))
            .OrderBy(hotel => hotel.Name)
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

    public async Task<IReadOnlyCollection<HotelStaffMemberDto>> GetStaffAsync(Guid hotelId, CancellationToken cancellationToken)
    {
        List<HotelStaffMemberDto> staff = await (
            from assignment in _dbContext.HotelStaffAssignments.IgnoreQueryFilters().AsNoTracking()
            join user in _dbContext.UserAccounts.IgnoreQueryFilters().AsNoTracking()
                on assignment.UserAccountId equals user.Id
            join role in _dbContext.UserRoles.IgnoreQueryFilters().AsNoTracking()
                on assignment.RoleId equals role.Id
            where assignment.HotelId == hotelId && assignment.IsActive
            orderby role.Name, user.FullName
            select new HotelStaffMemberDto(
                user.Id,
                assignment.Id,
                assignment.HotelId,
                user.Email,
                user.FullName,
                user.PhoneNumber,
                ParseRoleCode(role.Code),
                user.Status,
                assignment.AssignedAtUtc))
            .ToListAsync(cancellationToken);

        return staff;
    }

    public Task<bool> EmailExistsAsync(string email, CancellationToken cancellationToken)
    {
        return _dbContext.UserAccounts
            .IgnoreQueryFilters()
            .AnyAsync(user => user.Email == email, cancellationToken);
    }

    public Task<bool> PhoneNumberExistsAsync(string phoneNumber, CancellationToken cancellationToken)
    {
        return _dbContext.UserAccounts
            .IgnoreQueryFilters()
            .AnyAsync(user => user.PhoneNumber == phoneNumber, cancellationToken);
    }

    public Task<UserRole?> GetRoleAsync(UserRoleCode roleCode, CancellationToken cancellationToken)
    {
        string roleCodeValue = roleCode.ToString().ToUpperInvariant();

        return _dbContext.UserRoles
            .IgnoreQueryFilters()
            .AsNoTracking()
            .FirstOrDefaultAsync(role => role.Code == roleCodeValue, cancellationToken);
    }

    public async Task<HotelStaffMemberDto> CreateStaffAsync(
        Guid hotelId,
        UserAccount userAccount,
        Guid roleId,
        Guid assignedByUserAccountId,
        UserRoleCode roleCode,
        CancellationToken cancellationToken)
    {
        IExecutionStrategy executionStrategy = _dbContext.Database.CreateExecutionStrategy();

        return await executionStrategy.ExecuteAsync(async () =>
        {
            await using IDbContextTransaction transaction = await _dbContext.Database.BeginTransactionAsync(
                IsolationLevel.Serializable,
                cancellationToken);

            UserAccountRole userAccountRole = new(Guid.NewGuid(), userAccount.Id, roleId);
            HotelStaffAssignment assignment = new(Guid.NewGuid(), userAccount.Id, hotelId, roleId, assignedByUserAccountId);

            await _dbContext.UserAccounts.AddAsync(userAccount, cancellationToken);
            await _dbContext.UserAccountRoles.AddAsync(userAccountRole, cancellationToken);
            await _dbContext.HotelStaffAssignments.AddAsync(assignment, cancellationToken);
            await _dbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);

            return new HotelStaffMemberDto(
                userAccount.Id,
                assignment.Id,
                hotelId,
                userAccount.Email,
                userAccount.FullName,
                userAccount.PhoneNumber,
                roleCode,
                userAccount.Status,
                assignment.AssignedAtUtc);
        });
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

    public async Task<PhysicalRoomPersistenceResult> CreatePhysicalRoomAsync(
        Guid hotelId,
        Guid roomTypeId,
        string roomNumber,
        RoomOperationalStatus initialStatus,
        CancellationToken cancellationToken)
    {
        IExecutionStrategy executionStrategy = _dbContext.Database.CreateExecutionStrategy();

        return await executionStrategy.ExecuteAsync(async () =>
        {
            await using IDbContextTransaction transaction = await _dbContext.Database.BeginTransactionAsync(
                IsolationLevel.Serializable,
                cancellationToken);

            string normalizedRoomNumber = roomNumber.Trim();
            bool roomNumberLockAcquired = await SqlApplicationLock.AcquireExclusiveAsync(
                _dbContext,
                $"physical-room-number:{hotelId:N}:{normalizedRoomNumber.ToUpperInvariant()}",
                cancellationToken);
            if (!roomNumberLockAcquired)
            {
                await transaction.RollbackAsync(cancellationToken);
                return PhysicalRoomPersistenceResult.Failure(PhysicalRoomPersistenceStatus.LockUnavailable);
            }

            bool roomTypeExists = await _dbContext.RoomTypes
                .AnyAsync(roomType => roomType.HotelId == hotelId &&
                    roomType.Id == roomTypeId &&
                    roomType.Status == RecordStatus.Active,
                    cancellationToken);

            if (!roomTypeExists)
            {
                await transaction.RollbackAsync(cancellationToken);
                return PhysicalRoomPersistenceResult.Failure(PhysicalRoomPersistenceStatus.RoomTypeNotFound);
            }

            bool duplicateRoomNumber = await _dbContext.PhysicalRooms
                .AnyAsync(room => room.HotelId == hotelId && room.RoomNumber == normalizedRoomNumber, cancellationToken);

            if (duplicateRoomNumber)
            {
                await transaction.RollbackAsync(cancellationToken);
                return PhysicalRoomPersistenceResult.Failure(PhysicalRoomPersistenceStatus.DuplicateRoomNumber);
            }

            PhysicalRoom physicalRoom;
            try
            {
                physicalRoom = new PhysicalRoom(Guid.NewGuid(), hotelId, roomTypeId, normalizedRoomNumber, initialStatus);
            }
            catch (SharedKernel.Exceptions.DomainException)
            {
                await transaction.RollbackAsync(cancellationToken);
                return PhysicalRoomPersistenceResult.Failure(PhysicalRoomPersistenceStatus.InvalidRoomStatus);
            }

            await _dbContext.PhysicalRooms.AddAsync(physicalRoom, cancellationToken);
            await _dbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);

            return PhysicalRoomPersistenceResult.Success(physicalRoom);
        });
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

    public async Task<PhysicalRoomPersistenceResult> UpdatePhysicalRoomAsync(
        Guid hotelId,
        Guid physicalRoomId,
        string roomNumber,
        RoomOperationalStatus status,
        CancellationToken cancellationToken)
    {
        IExecutionStrategy executionStrategy = _dbContext.Database.CreateExecutionStrategy();

        return await executionStrategy.ExecuteAsync(async () =>
        {
            await using IDbContextTransaction transaction = await _dbContext.Database.BeginTransactionAsync(
                IsolationLevel.Serializable,
                cancellationToken);

            bool roomLockAcquired = await SqlApplicationLock.AcquireRoomLocksAsync(
                _dbContext,
                hotelId,
                new[] { physicalRoomId },
                cancellationToken);
            if (!roomLockAcquired)
            {
                await transaction.RollbackAsync(cancellationToken);
                return PhysicalRoomPersistenceResult.Failure(PhysicalRoomPersistenceStatus.LockUnavailable);
            }

            string normalizedRoomNumber = roomNumber.Trim();
            bool roomNumberLockAcquired = await SqlApplicationLock.AcquireExclusiveAsync(
                _dbContext,
                $"physical-room-number:{hotelId:N}:{normalizedRoomNumber.ToUpperInvariant()}",
                cancellationToken);
            if (!roomNumberLockAcquired)
            {
                await transaction.RollbackAsync(cancellationToken);
                return PhysicalRoomPersistenceResult.Failure(PhysicalRoomPersistenceStatus.LockUnavailable);
            }

            PhysicalRoom? physicalRoom = await _dbContext.PhysicalRooms
                .FirstOrDefaultAsync(room => room.HotelId == hotelId && room.Id == physicalRoomId, cancellationToken);

            if (physicalRoom is null)
            {
                await transaction.RollbackAsync(cancellationToken);
                return PhysicalRoomPersistenceResult.Failure(PhysicalRoomPersistenceStatus.PhysicalRoomNotFound);
            }

            if (status == RoomOperationalStatus.Inactive && physicalRoom.Status == RoomOperationalStatus.Occupied)
            {
                await transaction.RollbackAsync(cancellationToken);
                return PhysicalRoomPersistenceResult.Failure(PhysicalRoomPersistenceStatus.RoomIsOccupied);
            }

            bool duplicateRoomNumber = await _dbContext.PhysicalRooms
                .AsNoTracking()
                .AnyAsync(room => room.HotelId == hotelId &&
                    room.RoomNumber == normalizedRoomNumber &&
                    room.Id != physicalRoomId,
                    cancellationToken);

            if (duplicateRoomNumber)
            {
                await transaction.RollbackAsync(cancellationToken);
                return PhysicalRoomPersistenceResult.Failure(PhysicalRoomPersistenceStatus.DuplicateRoomNumber);
            }

            try
            {
                physicalRoom.Rename(normalizedRoomNumber);
                physicalRoom.ChangeSetupStatus(status);
            }
            catch (SharedKernel.Exceptions.DomainException)
            {
                await transaction.RollbackAsync(cancellationToken);
                return PhysicalRoomPersistenceResult.Failure(PhysicalRoomPersistenceStatus.InvalidRoomStatus);
            }

            await _dbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);

            return PhysicalRoomPersistenceResult.Success(physicalRoom);
        });
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

    private static UserRoleCode ParseRoleCode(string roleCode)
    {
        return Enum.TryParse(roleCode, ignoreCase: true, out UserRoleCode parsedRole)
            ? parsedRole
            : UserRoleCode.Receptionist;
    }
}
