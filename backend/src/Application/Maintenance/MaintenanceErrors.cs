using HotelMarketplace.SharedKernel.Results;

namespace HotelMarketplace.Application.Maintenance;

public static class MaintenanceErrors
{
    public static readonly ResultError Forbidden = new("Maintenance.Forbidden", "The current user is not allowed to perform maintenance operations for this hotel.");
    public static readonly ResultError RequestNotFound = new("Maintenance.RequestNotFound", "The maintenance request was not found.");
    public static readonly ResultError RoomNotFound = new("Maintenance.RoomNotFound", "The physical room was not found.");
    public static readonly ResultError InvalidTransition = new("Maintenance.InvalidTransition", "The selected maintenance status transition is not allowed.");
    public static readonly ResultError InvalidRoomStatus = new("Maintenance.InvalidRoomStatus", "The selected room status transition is not allowed.");
    public static readonly ResultError LockUnavailable = new("Maintenance.LockUnavailable", "The maintenance request is busy. Please try again.");
}
