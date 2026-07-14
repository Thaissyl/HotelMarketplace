using HotelMarketplace.SharedKernel.Results;

namespace HotelMarketplace.Application.FrontDesk;

public static class FrontDeskErrors
{
    public static readonly ResultError Forbidden = new("FrontDesk.Forbidden", "The current user is not allowed to perform front desk operations for this hotel.");
    public static readonly ResultError BookingNotFound = new("FrontDesk.BookingNotFound", "The booking was not found.");
    public static readonly ResultError RoomTypeNotAvailable = new("FrontDesk.RoomTypeNotAvailable", "The room type is not available for this hotel.");
    public static readonly ResultError InvalidBookingStatusForCheckIn = new("FrontDesk.InvalidBookingStatusForCheckIn", "Only confirmed bookings can be checked in.");
    public static readonly ResultError InvalidBookingStatusForCheckOut = new("FrontDesk.InvalidBookingStatusForCheckOut", "Only checked-in bookings can be checked out.");
    public static readonly ResultError InvalidRoomAssignment = new("FrontDesk.InvalidRoomAssignment", "Selected physical rooms must be available, belong to the booked room type, and match the booked quantity.");
    public static readonly ResultError RoomAssignmentOverlap = new("FrontDesk.RoomAssignmentOverlap", "This physical room is already assigned to another active stay for the selected dates.");
    public static readonly ResultError PaymentCollectionRequired = new("FrontDesk.PaymentCollectionRequired", "Please confirm payment collection before checkout.");
    public static readonly ResultError CapacityExceeded = new("FrontDesk.CapacityExceeded", "The guest count exceeds the selected room type capacity.");
    public static readonly ResultError LockUnavailable = new("FrontDesk.LockUnavailable", "The front desk operation is busy. Please try again.");
}
