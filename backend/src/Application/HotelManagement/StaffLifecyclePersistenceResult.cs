using HotelMarketplace.Application.HotelManagement.Dtos;

namespace HotelMarketplace.Application.HotelManagement;

public enum StaffLifecyclePersistenceStatus
{
    Success = 0,
    UserNotFound = 1,
    AssignmentNotFound = 2,
    DuplicateAssignment = 3,
    DuplicateEmail = 4,
    DuplicatePhoneNumber = 5,
    SystemAccountForbidden = 6,
    PlatformAdministratorForbidden = 7,
    AccountInactive = 8,
    OpenTasks = 9,
    LockUnavailable = 10,
    SelfManagementForbidden = 11,
    ManagerRoleManagementForbidden = 12,
    InactiveAssignment = 13,
    ActorAccessRevoked = 14
}

public sealed record StaffLifecyclePersistenceResult(
    StaffLifecyclePersistenceStatus Status,
    HotelStaffMemberDto? Staff)
{
    public static StaffLifecyclePersistenceResult Success(HotelStaffMemberDto staff) =>
        new(StaffLifecyclePersistenceStatus.Success, staff);

    public static StaffLifecyclePersistenceResult Failure(StaffLifecyclePersistenceStatus status) =>
        new(status, null);
}
