using HotelMarketplace.SharedKernel.Results;

namespace HotelMarketplace.Application.Bookings;

public static class BookingErrors
{
    public static readonly ResultError Forbidden = new("Booking.Forbidden", "The current user is not allowed to create customer bookings.");
    public static readonly ResultError HotelNotAvailable = new("Booking.HotelNotAvailable", "The hotel is not available for booking.");
    public static readonly ResultError RoomTypeNotAvailable = new("Booking.RoomTypeNotAvailable", "The room type is not available for booking.");
    public static readonly ResultError CapacityExceeded = new("Booking.CapacityExceeded", "The requested guest count exceeds the selected room type capacity.");
    public static readonly ResultError InsufficientAvailability = new("Booking.InsufficientAvailability", "There are not enough rooms available for the selected dates.");
    public static readonly ResultError ReservationLockUnavailable = new("Booking.ReservationLockUnavailable", "The booking inventory is busy. Please try again.");
    public static readonly ResultError BookingNotFound = new("Booking.BookingNotFound", "The booking was not found.");
    public static readonly ResultError InvalidCancellationStatus = new("Booking.InvalidCancellationStatus", "Only pending payment or confirmed bookings can be cancelled.");
    public static readonly ResultError InvalidCancellationRequest = new("Booking.InvalidCancellationRequest", "The cancellation request is invalid.");
    public static readonly ResultError CancellationLockUnavailable = new("Booking.CancellationLockUnavailable", "The booking is being updated. Please try again.");
}
