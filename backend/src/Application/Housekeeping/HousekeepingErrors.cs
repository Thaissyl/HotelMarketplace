using HotelMarketplace.SharedKernel.Results;

namespace HotelMarketplace.Application.Housekeeping;

public static class HousekeepingErrors
{
    public static readonly ResultError Forbidden = new("Housekeeping.Forbidden", "The current user is not allowed to perform housekeeping operations for this hotel.");
    public static readonly ResultError TaskNotFound = new("Housekeeping.TaskNotFound", "The housekeeping task was not found.");
    public static readonly ResultError InvalidTransition = new("Housekeeping.InvalidTransition", "The selected cleaning status transition is not allowed.");
    public static readonly ResultError RoomNotFound = new("Housekeeping.RoomNotFound", "The physical room was not found.");
    public static readonly ResultError AssigneeNotFound = new("Housekeeping.AssigneeNotFound", "The selected user is not an active housekeeping staff member for this hotel.");
    public static readonly ResultError AssigneeOwnershipConflict = new("Housekeeping.AssigneeOwnershipConflict", "This task is assigned to another housekeeper. Ask a hotel manager to reassign or override it.");
    public static readonly ResultError LockUnavailable = new("Housekeeping.LockUnavailable", "The housekeeping task is busy. Please try again.");
}
