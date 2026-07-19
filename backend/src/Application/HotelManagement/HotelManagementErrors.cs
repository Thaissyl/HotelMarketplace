using HotelMarketplace.SharedKernel.Results;

namespace HotelMarketplace.Application.HotelManagement;

public static class HotelManagementErrors
{
    public static readonly ResultError Forbidden = new("HotelManagement.Forbidden", "The current user is not allowed to manage this hotel resource.");
    public static readonly ResultError HotelNotFound = new("HotelManagement.HotelNotFound", "The hotel was not found.");
    public static readonly ResultError RoomTypeNotFound = new("HotelManagement.RoomTypeNotFound", "The room type was not found.");
    public static readonly ResultError PhysicalRoomNotFound = new("HotelManagement.PhysicalRoomNotFound", "The physical room was not found.");
    public static readonly ResultError DuplicateRoomNumber = new("HotelManagement.DuplicateRoomNumber", "Room number must be unique within the hotel.");
    public static readonly ResultError RoomTypeHasFutureBookings = new("HotelManagement.RoomTypeHasFutureBookings", "This room type cannot be deactivated because active future bookings exist.");
    public static readonly ResultError RoomIsOccupied = new("HotelManagement.RoomIsOccupied", "This room cannot be inactivated because it is currently occupied.");
    public static readonly ResultError OperationalLifecycleActive = new("HotelManagement.OperationalLifecycleActive", "Room availability cannot be changed from setup while an assignment, cleaning task, or maintenance workflow is active.");
    public static readonly ResultError LockUnavailable = new("HotelManagement.LockUnavailable", "The room is being updated by another operation. Please retry.");
    public static readonly ResultError DuplicateStaffEmail = new("HotelManagement.DuplicateStaffEmail", "A user account with this email already exists.");
    public static readonly ResultError DuplicateStaffPhoneNumber = new("HotelManagement.DuplicateStaffPhoneNumber", "A user account with this phone number already exists.");
    public static readonly ResultError InvalidStaffRole = new("HotelManagement.InvalidStaffRole", "The selected staff role is not valid for hotel operations.");
    public static readonly ResultError StaffNotFound = new("HotelManagement.StaffNotFound", "The hotel staff assignment was not found.");
    public static readonly ResultError StaffUserNotFound = new("HotelManagement.StaffUserNotFound", "No user account exists with the supplied email address.");
    public static readonly ResultError DuplicateStaffAssignment = new("HotelManagement.DuplicateStaffAssignment", "This user already has an active assignment at the hotel.");
    public static readonly ResultError StaffSystemAccountForbidden = new("HotelManagement.StaffSystemAccountForbidden", "System accounts cannot be assigned as hotel staff.");
    public static readonly ResultError StaffPlatformAdministratorForbidden = new("HotelManagement.StaffPlatformAdministratorForbidden", "Platform Administrator accounts cannot be assigned to hotel operations.");
    public static readonly ResultError StaffAccountInactive = new("HotelManagement.StaffAccountInactive", "The user account must be active before it can be assigned to a hotel.");
    public static readonly ResultError StaffHasOpenTasks = new("HotelManagement.StaffHasOpenTasks", "Reassign or complete this staff member's open tasks before changing or deactivating the assignment.");
    public static readonly ResultError SelfManagementForbidden = new("HotelManagement.SelfManagementForbidden", "Hotel Managers cannot change or deactivate their own assignment.");
    public static readonly ResultError ManagerRoleManagementForbidden = new("HotelManagement.ManagerRoleManagementForbidden", "Hotel Managers can manage Receptionist, Housekeeping Staff, and Maintenance Staff assignments only.");
    public static readonly ResultError InactiveStaffAssignment = new("HotelManagement.InactiveStaffAssignment", "Reactivate the staff assignment before changing its role.");
}
