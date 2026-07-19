using HotelMarketplace.SharedKernel.Results;

namespace HotelMarketplace.Application.Availability;

internal static class AvailabilityErrors
{
    public static readonly ResultError Forbidden = new(
        "Availability.Forbidden",
        "You are not authorized to manage availability for this hotel.");

    public static readonly ResultError InvalidRequest = new(
        "Availability.InvalidRequest",
        "The availability request is invalid.");

    public static readonly ResultError HotelNotFound = new(
        "Availability.HotelNotFound",
        "The hotel was not found.");

    public static readonly ResultError RoomTypeNotFound = new(
        "Availability.RoomTypeNotFound",
        "The selected room type was not found.");

    public static readonly ResultError PhysicalRoomNotFound = new(
        "Availability.PhysicalRoomNotFound",
        "The selected physical room was not found for this room type.");

    public static readonly ResultError ActiveBookingConflict = new(
        "Availability.ActiveBookingConflict",
        "Availability change conflicts with an active booking or assignment.");

    public static readonly ResultError LockUnavailable = new(
        "Availability.LockUnavailable",
        "Availability is being changed by another operation. Please try again.");
}
