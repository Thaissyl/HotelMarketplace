using HotelMarketplace.SharedKernel.Results;

namespace HotelMarketplace.Application.CustomerEngagement;

public static class CustomerEngagementErrors
{
    public static readonly ResultError Unauthenticated = new(
        "CustomerEngagement.Unauthenticated",
        "An authenticated account is required.");
    public static readonly ResultError HotelNotFound = new(
        "CustomerEngagement.HotelNotFound",
        "The hotel is not available to save.");
    public static readonly ResultError NotificationNotFound = new(
        "CustomerEngagement.NotificationNotFound",
        "The notification was not found.");
}
