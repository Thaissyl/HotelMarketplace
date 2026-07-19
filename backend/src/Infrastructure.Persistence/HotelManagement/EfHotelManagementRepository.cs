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
            where assignment.HotelId == hotelId
            orderby assignment.IsActive descending, role.Name, user.FullName
            select new HotelStaffMemberDto(
                user.Id,
                assignment.Id,
                assignment.HotelId,
                user.Email,
                user.FullName,
                user.PhoneNumber,
                ParseRoleCode(role.Code),
                user.Status,
                assignment.IsActive,
                assignment.AssignedAtUtc))
            .ToListAsync(cancellationToken);

        return staff
            .GroupBy(member => member.UserAccountId)
            .Select(group => group
                .OrderByDescending(member => member.IsAssignmentActive)
                .ThenByDescending(member => member.AssignedAtUtc)
                .First())
            .OrderBy(member => member.Role)
            .ThenBy(member => member.FullName)
            .ToArray();
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

    public async Task<StaffLifecyclePersistenceResult> CreateStaffAsync(
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

            if (!await SqlApplicationLock.AcquireExclusiveAsync(
                    _dbContext,
                    $"staff-email:{userAccount.Email.ToUpperInvariant()}",
                    cancellationToken) ||
                !await SqlApplicationLock.AcquireExclusiveAsync(
                    _dbContext,
                    $"staff-phone:{userAccount.PhoneNumber}",
                    cancellationToken))
            {
                await transaction.RollbackAsync(cancellationToken);
                return StaffLifecyclePersistenceResult.Failure(StaffLifecyclePersistenceStatus.LockUnavailable);
            }

            UserRoleCode? actorRole = await GetTransactionalStaffManagerRoleAsync(
                hotelId,
                assignedByUserAccountId,
                cancellationToken);
            if (!actorRole.HasValue)
            {
                await transaction.RollbackAsync(cancellationToken);
                return StaffLifecyclePersistenceResult.Failure(StaffLifecyclePersistenceStatus.ActorAccessRevoked);
            }
            if (!CanManageStaffRole(actorRole.Value, roleCode))
            {
                await transaction.RollbackAsync(cancellationToken);
                return StaffLifecyclePersistenceResult.Failure(StaffLifecyclePersistenceStatus.ManagerRoleManagementForbidden);
            }

            if (await _dbContext.UserAccounts.IgnoreQueryFilters().AnyAsync(user => user.Email == userAccount.Email, cancellationToken))
            {
                await transaction.RollbackAsync(cancellationToken);
                return StaffLifecyclePersistenceResult.Failure(StaffLifecyclePersistenceStatus.DuplicateEmail);
            }
            if (userAccount.PhoneNumber is not null && await _dbContext.UserAccounts.IgnoreQueryFilters()
                .AnyAsync(user => user.PhoneNumber == userAccount.PhoneNumber, cancellationToken))
            {
                await transaction.RollbackAsync(cancellationToken);
                return StaffLifecyclePersistenceResult.Failure(StaffLifecyclePersistenceStatus.DuplicatePhoneNumber);
            }

            UserAccountRole userAccountRole = new(Guid.NewGuid(), userAccount.Id, roleId);
            HotelStaffAssignment assignment = new(Guid.NewGuid(), userAccount.Id, hotelId, roleId, assignedByUserAccountId);

            await _dbContext.UserAccounts.AddAsync(userAccount, cancellationToken);
            await _dbContext.UserAccountRoles.AddAsync(userAccountRole, cancellationToken);
            await _dbContext.HotelStaffAssignments.AddAsync(assignment, cancellationToken);
            await _dbContext.NotificationRecords.AddAsync(
                new NotificationRecord(
                    Guid.NewGuid(),
                    userAccount.Id,
                    "HotelStaffAssigned",
                    nameof(HotelStaffAssignment),
                    assignment.Id,
                    $"You were assigned the {roleCode} role at a hotel.",
                    hotelId),
                cancellationToken);
            await _dbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);

            return StaffLifecyclePersistenceResult.Success(new HotelStaffMemberDto(
                userAccount.Id,
                assignment.Id,
                hotelId,
                userAccount.Email,
                userAccount.FullName,
                userAccount.PhoneNumber,
                roleCode,
                userAccount.Status,
                assignment.IsActive,
                assignment.AssignedAtUtc));
        });
    }

    public async Task<StaffLifecyclePersistenceResult> AttachStaffAsync(
        Guid hotelId,
        string normalizedEmail,
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

            if (!await SqlApplicationLock.AcquireExclusiveAsync(
                    _dbContext,
                    $"staff-email:{normalizedEmail.ToUpperInvariant()}",
                    cancellationToken))
            {
                await transaction.RollbackAsync(cancellationToken);
                return StaffLifecyclePersistenceResult.Failure(StaffLifecyclePersistenceStatus.LockUnavailable);
            }

            UserAccount? user = await _dbContext.UserAccounts
                .IgnoreQueryFilters()
                .FirstOrDefaultAsync(entity => entity.Email == normalizedEmail, cancellationToken);
            if (user is null)
            {
                await transaction.RollbackAsync(cancellationToken);
                return StaffLifecyclePersistenceResult.Failure(StaffLifecyclePersistenceStatus.UserNotFound);
            }
            if (!await AcquireStaffAssignmentLockAsync(hotelId, user.Id, cancellationToken))
            {
                await transaction.RollbackAsync(cancellationToken);
                return StaffLifecyclePersistenceResult.Failure(StaffLifecyclePersistenceStatus.LockUnavailable);
            }
            UserRoleCode? actorRole = await GetTransactionalStaffManagerRoleAsync(
                hotelId,
                assignedByUserAccountId,
                cancellationToken);
            if (!actorRole.HasValue)
            {
                await transaction.RollbackAsync(cancellationToken);
                return StaffLifecyclePersistenceResult.Failure(StaffLifecyclePersistenceStatus.ActorAccessRevoked);
            }
            if (!CanManageStaffRole(actorRole.Value, roleCode))
            {
                await transaction.RollbackAsync(cancellationToken);
                return StaffLifecyclePersistenceResult.Failure(StaffLifecyclePersistenceStatus.ManagerRoleManagementForbidden);
            }
            if (user.IsSystemAccount)
            {
                await transaction.RollbackAsync(cancellationToken);
                return StaffLifecyclePersistenceResult.Failure(StaffLifecyclePersistenceStatus.SystemAccountForbidden);
            }
            if (user.Status != AccountStatus.Active)
            {
                await transaction.RollbackAsync(cancellationToken);
                return StaffLifecyclePersistenceResult.Failure(StaffLifecyclePersistenceStatus.AccountInactive);
            }
            if (await HasActivePlatformAdministratorRoleAsync(user.Id, cancellationToken))
            {
                await transaction.RollbackAsync(cancellationToken);
                return StaffLifecyclePersistenceResult.Failure(StaffLifecyclePersistenceStatus.PlatformAdministratorForbidden);
            }

            HotelStaffAssignment? assignment = await _dbContext.HotelStaffAssignments
                .IgnoreQueryFilters()
                .Where(entity => entity.HotelId == hotelId && entity.UserAccountId == user.Id)
                .OrderByDescending(entity => entity.IsActive)
                .ThenByDescending(entity => entity.AssignedAtUtc)
                .FirstOrDefaultAsync(cancellationToken);
            if (assignment?.IsActive == true)
            {
                await transaction.RollbackAsync(cancellationToken);
                return StaffLifecyclePersistenceResult.Failure(StaffLifecyclePersistenceStatus.DuplicateAssignment);
            }

            Guid? previousRoleId = assignment?.RoleId;
            if (assignment is null)
            {
                assignment = new HotelStaffAssignment(Guid.NewGuid(), user.Id, hotelId, roleId, assignedByUserAccountId);
                await _dbContext.HotelStaffAssignments.AddAsync(assignment, cancellationToken);
            }
            else
            {
                assignment.Reactivate(roleId);
            }

            await EnsureGlobalRoleActiveAsync(user.Id, roleId, cancellationToken);
            if (previousRoleId.HasValue && previousRoleId.Value != roleId)
            {
                await RevokeGlobalRoleIfUnusedAsync(user.Id, previousRoleId.Value, assignment.Id, cancellationToken);
            }
            await AddStaffNotificationAsync(user.Id, assignment.Id, hotelId, "HotelStaffAssigned", roleCode, cancellationToken);
            await _dbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);

            return StaffLifecyclePersistenceResult.Success(
                new HotelStaffMemberDto(
                    user.Id,
                    assignment.Id,
                    hotelId,
                    user.Email,
                    user.FullName,
                    user.PhoneNumber,
                    roleCode,
                    user.Status,
                    assignment.IsActive,
                    assignment.AssignedAtUtc));
        });
    }

    public async Task<StaffLifecyclePersistenceResult> UpdateStaffAssignmentAsync(
        Guid hotelId,
        Guid assignmentId,
        Guid? targetRoleId,
        UserRoleCode? targetRoleCode,
        bool? isActive,
        Guid actorUserAccountId,
        CancellationToken cancellationToken)
    {
        IExecutionStrategy executionStrategy = _dbContext.Database.CreateExecutionStrategy();

        return await executionStrategy.ExecuteAsync(async () =>
        {
            await using IDbContextTransaction transaction = await _dbContext.Database.BeginTransactionAsync(
                IsolationLevel.Serializable,
                cancellationToken);

            if (!await SqlApplicationLock.AcquireExclusiveAsync(
                    _dbContext,
                    $"staff-assignment:{hotelId:N}:{assignmentId:N}",
                    cancellationToken))
            {
                await transaction.RollbackAsync(cancellationToken);
                return StaffLifecyclePersistenceResult.Failure(StaffLifecyclePersistenceStatus.LockUnavailable);
            }

            HotelStaffAssignment? assignment = await _dbContext.HotelStaffAssignments
                .IgnoreQueryFilters()
                .FirstOrDefaultAsync(entity => entity.Id == assignmentId && entity.HotelId == hotelId, cancellationToken);
            if (assignment is null)
            {
                await transaction.RollbackAsync(cancellationToken);
                return StaffLifecyclePersistenceResult.Failure(StaffLifecyclePersistenceStatus.AssignmentNotFound);
            }
            if (!await AcquireStaffAssignmentLockAsync(hotelId, assignment.UserAccountId, cancellationToken))
            {
                await transaction.RollbackAsync(cancellationToken);
                return StaffLifecyclePersistenceResult.Failure(StaffLifecyclePersistenceStatus.LockUnavailable);
            }
            UserRoleCode? actorRole = await GetTransactionalStaffManagerRoleAsync(
                hotelId,
                actorUserAccountId,
                cancellationToken);
            if (!actorRole.HasValue)
            {
                await transaction.RollbackAsync(cancellationToken);
                return StaffLifecyclePersistenceResult.Failure(StaffLifecyclePersistenceStatus.ActorAccessRevoked);
            }
            bool canManageHotelManagers = actorRole.Value == UserRoleCode.PropertyOwner;
            if (!canManageHotelManagers && assignment.UserAccountId == actorUserAccountId)
            {
                await transaction.RollbackAsync(cancellationToken);
                return StaffLifecyclePersistenceResult.Failure(StaffLifecyclePersistenceStatus.SelfManagementForbidden);
            }

            UserRole currentRole = await _dbContext.UserRoles.IgnoreQueryFilters().AsNoTracking()
                .SingleAsync(role => role.Id == assignment.RoleId, cancellationToken);
            UserRoleCode currentRoleCode = ParseRoleCode(currentRole.Code);
            if (!canManageHotelManagers &&
                (currentRoleCode == UserRoleCode.HotelManager || targetRoleCode == UserRoleCode.HotelManager))
            {
                await transaction.RollbackAsync(cancellationToken);
                return StaffLifecyclePersistenceResult.Failure(StaffLifecyclePersistenceStatus.ManagerRoleManagementForbidden);
            }

            UserAccount user = await _dbContext.UserAccounts.IgnoreQueryFilters()
                .SingleAsync(entity => entity.Id == assignment.UserAccountId, cancellationToken);
            if (targetRoleId.HasValue && !assignment.IsActive)
            {
                await transaction.RollbackAsync(cancellationToken);
                return StaffLifecyclePersistenceResult.Failure(StaffLifecyclePersistenceStatus.InactiveAssignment);
            }
            if (isActive == true && user.Status != AccountStatus.Active)
            {
                await transaction.RollbackAsync(cancellationToken);
                return StaffLifecyclePersistenceResult.Failure(StaffLifecyclePersistenceStatus.AccountInactive);
            }

            bool removesCurrentOperationalRole = isActive == false ||
                (targetRoleId.HasValue && targetRoleId.Value != assignment.RoleId);
            if (removesCurrentOperationalRole && await HasOpenStaffTasksAsync(hotelId, user.Id, cancellationToken))
            {
                await transaction.RollbackAsync(cancellationToken);
                return StaffLifecyclePersistenceResult.Failure(StaffLifecyclePersistenceStatus.OpenTasks);
            }

            Guid previousRoleId = assignment.RoleId;
            UserRoleCode resultingRoleCode = targetRoleCode ?? currentRoleCode;
            string eventType;
            if (targetRoleId.HasValue)
            {
                assignment.ChangeRole(targetRoleId.Value);
                await EnsureGlobalRoleActiveAsync(user.Id, targetRoleId.Value, cancellationToken);
                eventType = "HotelStaffRoleChanged";
            }
            else if (isActive == true)
            {
                assignment.Reactivate(assignment.RoleId);
                await EnsureGlobalRoleActiveAsync(user.Id, assignment.RoleId, cancellationToken);
                eventType = "HotelStaffReactivated";
            }
            else
            {
                assignment.Revoke();
                eventType = "HotelStaffDeactivated";
            }

            if (previousRoleId != assignment.RoleId || !assignment.IsActive)
            {
                await RevokeGlobalRoleIfUnusedAsync(user.Id, previousRoleId, assignment.Id, cancellationToken);
            }

            await AddStaffNotificationAsync(user.Id, assignment.Id, hotelId, eventType, resultingRoleCode, cancellationToken);
            await _dbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);

            return StaffLifecyclePersistenceResult.Success(new HotelStaffMemberDto(
                user.Id,
                assignment.Id,
                hotelId,
                user.Email,
                user.FullName,
                user.PhoneNumber,
                resultingRoleCode,
                user.Status,
                assignment.IsActive,
                assignment.AssignedAtUtc));
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

            if (status != physicalRoom.Status)
            {
                bool hasActiveLifecycle = await _dbContext.BookingRoomAssignments
                    .IgnoreQueryFilters()
                    .AsNoTracking()
                    .AnyAsync(assignment => assignment.PhysicalRoomId == physicalRoomId && assignment.Status == RecordStatus.Active, cancellationToken)
                    || await _dbContext.HousekeepingTasks
                        .IgnoreQueryFilters()
                        .AsNoTracking()
                        .AnyAsync(task => task.PhysicalRoomId == physicalRoomId &&
                            task.Status != HousekeepingTaskStatus.Completed &&
                            task.Status != HousekeepingTaskStatus.Cancelled,
                            cancellationToken)
                    || await _dbContext.MaintenanceRequests
                        .IgnoreQueryFilters()
                        .AsNoTracking()
                        .AnyAsync(request => request.PhysicalRoomId == physicalRoomId &&
                            request.Status != MaintenanceStatus.Released &&
                            request.Status != MaintenanceStatus.Cancelled,
                            cancellationToken);
                if (hasActiveLifecycle)
                {
                    await transaction.RollbackAsync(cancellationToken);
                    return PhysicalRoomPersistenceResult.Failure(PhysicalRoomPersistenceStatus.OperationalLifecycleActive);
                }
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

    private Task<bool> AcquireStaffAssignmentLockAsync(
        Guid hotelId,
        Guid userAccountId,
        CancellationToken cancellationToken)
    {
        return SqlApplicationLock.AcquireExclusiveAsync(
            _dbContext,
            $"staff-assignment-user:{hotelId:N}:{userAccountId:N}",
            cancellationToken);
    }

    private async Task<UserRoleCode?> GetTransactionalStaffManagerRoleAsync(
        Guid hotelId,
        Guid actorUserAccountId,
        CancellationToken cancellationToken)
    {
        if (!await AcquireStaffAssignmentLockAsync(hotelId, actorUserAccountId, cancellationToken))
        {
            return null;
        }

        bool actorIsActive = await _dbContext.UserAccounts
            .IgnoreQueryFilters()
            .AsNoTracking()
            .AnyAsync(
                user => user.Id == actorUserAccountId && user.Status == AccountStatus.Active,
                cancellationToken);
        if (!actorIsActive)
        {
            return null;
        }

        bool ownsHotel = await _dbContext.HotelProperties
            .IgnoreQueryFilters()
            .AsNoTracking()
            .AnyAsync(
                hotel => hotel.Id == hotelId && hotel.OwnerUserAccountId == actorUserAccountId,
                cancellationToken);
        if (ownsHotel)
        {
            return UserRoleCode.PropertyOwner;
        }

        string managerCode = UserRoleCode.HotelManager.ToString().ToUpperInvariant();
        bool isActiveManager = await (
            from assignment in _dbContext.HotelStaffAssignments.IgnoreQueryFilters().AsNoTracking()
            join role in _dbContext.UserRoles.IgnoreQueryFilters().AsNoTracking()
                on assignment.RoleId equals role.Id
            where assignment.HotelId == hotelId &&
                assignment.UserAccountId == actorUserAccountId &&
                assignment.IsActive &&
                role.Code == managerCode
            select assignment.Id)
            .AnyAsync(cancellationToken);

        return isActiveManager ? UserRoleCode.HotelManager : null;
    }

    private static bool CanManageStaffRole(UserRoleCode actorRole, UserRoleCode targetRole)
    {
        bool targetIsOperational = targetRole is UserRoleCode.Receptionist or
                UserRoleCode.HousekeepingStaff or
                UserRoleCode.MaintenanceStaff;

        return actorRole == UserRoleCode.PropertyOwner
            ? targetRole == UserRoleCode.HotelManager || targetIsOperational
            : actorRole == UserRoleCode.HotelManager && targetIsOperational;
    }

    private Task<bool> HasActivePlatformAdministratorRoleAsync(
        Guid userAccountId,
        CancellationToken cancellationToken)
    {
        string platformRoleCode = UserRoleCode.PlatformAdministrator.ToString().ToUpperInvariant();

        return (
            from accountRole in _dbContext.UserAccountRoles.IgnoreQueryFilters().AsNoTracking()
            join role in _dbContext.UserRoles.IgnoreQueryFilters().AsNoTracking()
                on accountRole.RoleId equals role.Id
            where accountRole.UserAccountId == userAccountId &&
                accountRole.IsActive &&
                role.Code == platformRoleCode
            select accountRole.Id)
            .AnyAsync(cancellationToken);
    }

    private async Task<bool> HasOpenStaffTasksAsync(
        Guid hotelId,
        Guid userAccountId,
        CancellationToken cancellationToken)
    {
        bool hasHousekeepingTasks = await _dbContext.HousekeepingTasks
            .IgnoreQueryFilters()
            .AsNoTracking()
            .AnyAsync(task => task.HotelId == hotelId &&
                task.AssignedToUserAccountId == userAccountId &&
                task.Status != HousekeepingTaskStatus.Completed &&
                task.Status != HousekeepingTaskStatus.Cancelled,
                cancellationToken);
        if (hasHousekeepingTasks)
        {
            return true;
        }

        return await _dbContext.MaintenanceRequests
            .IgnoreQueryFilters()
            .AsNoTracking()
            .AnyAsync(request => request.HotelId == hotelId &&
                request.AssignedToUserAccountId == userAccountId &&
                request.Status != MaintenanceStatus.Resolved &&
                request.Status != MaintenanceStatus.Released &&
                request.Status != MaintenanceStatus.Cancelled,
                cancellationToken);
    }

    private async Task EnsureGlobalRoleActiveAsync(
        Guid userAccountId,
        Guid roleId,
        CancellationToken cancellationToken)
    {
        UserAccountRole? accountRole = await _dbContext.UserAccountRoles
            .IgnoreQueryFilters()
            .Where(entity => entity.UserAccountId == userAccountId && entity.RoleId == roleId)
            .OrderByDescending(entity => entity.IsActive)
            .ThenByDescending(entity => entity.AssignedAtUtc)
            .FirstOrDefaultAsync(cancellationToken);

        if (accountRole is null)
        {
            await _dbContext.UserAccountRoles.AddAsync(
                new UserAccountRole(Guid.NewGuid(), userAccountId, roleId),
                cancellationToken);
        }
        else if (!accountRole.IsActive)
        {
            accountRole.Reactivate();
        }
    }

    private async Task RevokeGlobalRoleIfUnusedAsync(
        Guid userAccountId,
        Guid roleId,
        Guid excludedAssignmentId,
        CancellationToken cancellationToken)
    {
        bool roleStillRequired = await _dbContext.HotelStaffAssignments
            .IgnoreQueryFilters()
            .AsNoTracking()
            .AnyAsync(assignment => assignment.UserAccountId == userAccountId &&
                assignment.RoleId == roleId &&
                assignment.IsActive &&
                assignment.Id != excludedAssignmentId,
                cancellationToken);
        if (roleStillRequired)
        {
            return;
        }

        UserAccountRole? accountRole = await _dbContext.UserAccountRoles
            .IgnoreQueryFilters()
            .Where(entity => entity.UserAccountId == userAccountId &&
                entity.RoleId == roleId &&
                entity.IsActive)
            .FirstOrDefaultAsync(cancellationToken);
        accountRole?.Revoke();
    }

    private async Task AddStaffNotificationAsync(
        Guid recipientUserAccountId,
        Guid assignmentId,
        Guid hotelId,
        string eventType,
        UserRoleCode roleCode,
        CancellationToken cancellationToken)
    {
        await _dbContext.NotificationRecords.AddAsync(
            new NotificationRecord(
                Guid.NewGuid(),
                recipientUserAccountId,
                eventType,
                nameof(HotelStaffAssignment),
                assignmentId,
                $"Your hotel staff assignment is now {roleCode} ({eventType}).",
                hotelId),
            cancellationToken);
    }

    private static UserRoleCode ParseRoleCode(string roleCode)
    {
        return Enum.TryParse(roleCode, ignoreCase: true, out UserRoleCode parsedRole)
            ? parsedRole
            : UserRoleCode.Receptionist;
    }
}
