using HotelMarketplace.Application.HotelManagement.Dtos;
using HotelMarketplace.Application.HotelManagement.Requests;
using HotelMarketplace.Domain.Entities;
using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.HotelManagement;

public interface IHotelManagementRepository
{
    Task AddHotelAsync(HotelProperty hotel, CancellationToken cancellationToken);

    Task<IReadOnlyCollection<HotelProperty>> GetHotelsOwnedByAsync(Guid ownerUserAccountId, CancellationToken cancellationToken);

    Task<IReadOnlyCollection<HotelProperty>> GetHotelsByIdsAsync(
        IReadOnlyCollection<Guid> hotelIds,
        CancellationToken cancellationToken);

    Task<HotelProperty?> GetHotelByIdAsync(Guid hotelId, CancellationToken cancellationToken);

    Task<bool> UserOwnsHotelAsync(Guid userAccountId, Guid hotelId, CancellationToken cancellationToken);

    Task<HotelContentDto?> GetHotelContentAsync(Guid hotelId, CancellationToken cancellationToken);

    Task<HotelContentPersistenceResult> ReplaceHotelContentAsync(
        Guid hotelId,
        UpdateHotelContentRequest request,
        Guid actorUserAccountId,
        CancellationToken cancellationToken);

    Task<IReadOnlyCollection<HotelStaffMemberDto>> GetStaffAsync(Guid hotelId, CancellationToken cancellationToken);

    Task<bool> EmailExistsAsync(string email, CancellationToken cancellationToken);

    Task<bool> PhoneNumberExistsAsync(string phoneNumber, CancellationToken cancellationToken);

    Task<UserRole?> GetRoleAsync(UserRoleCode roleCode, CancellationToken cancellationToken);

    Task<StaffLifecyclePersistenceResult> CreateStaffAsync(
        Guid hotelId,
        UserAccount userAccount,
        Guid roleId,
        Guid assignedByUserAccountId,
        UserRoleCode roleCode,
        CancellationToken cancellationToken);

    Task<StaffLifecyclePersistenceResult> AttachStaffAsync(
        Guid hotelId,
        string normalizedEmail,
        Guid roleId,
        Guid assignedByUserAccountId,
        UserRoleCode roleCode,
        CancellationToken cancellationToken);

    Task<StaffLifecyclePersistenceResult> UpdateStaffAssignmentAsync(
        Guid hotelId,
        Guid assignmentId,
        Guid? targetRoleId,
        UserRoleCode? targetRoleCode,
        bool? isActive,
        Guid actorUserAccountId,
        CancellationToken cancellationToken);

    Task AddRoomTypeAsync(RoomType roomType, CancellationToken cancellationToken);

    Task<IReadOnlyCollection<RoomType>> GetRoomTypesAsync(Guid hotelId, CancellationToken cancellationToken);

    Task<RoomType?> GetRoomTypeAsync(Guid hotelId, Guid roomTypeId, CancellationToken cancellationToken);

    Task<bool> RoomTypeHasActiveFutureBookingsAsync(Guid roomTypeId, DateOnly today, CancellationToken cancellationToken);

    Task AddPhysicalRoomAsync(PhysicalRoom physicalRoom, CancellationToken cancellationToken);

    Task<PhysicalRoomPersistenceResult> CreatePhysicalRoomAsync(
        Guid hotelId,
        Guid roomTypeId,
        string roomNumber,
        RoomOperationalStatus initialStatus,
        string? floor,
        string? notes,
        CancellationToken cancellationToken);

    Task<IReadOnlyCollection<PhysicalRoom>> GetPhysicalRoomsAsync(Guid hotelId, Guid? roomTypeId, CancellationToken cancellationToken);

    Task<PhysicalRoom?> GetPhysicalRoomAsync(Guid hotelId, Guid physicalRoomId, CancellationToken cancellationToken);

    Task<PhysicalRoomPersistenceResult> UpdatePhysicalRoomAsync(
        Guid hotelId,
        Guid physicalRoomId,
        string roomNumber,
        RoomOperationalStatus status,
        string? floor,
        string? notes,
        CancellationToken cancellationToken);

    Task<bool> RoomNumberExistsAsync(Guid hotelId, string roomNumber, Guid? excludedPhysicalRoomId, CancellationToken cancellationToken);

    Task SaveChangesAsync(CancellationToken cancellationToken);
}
