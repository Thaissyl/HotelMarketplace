using HotelMarketplace.Application.Marketplace;
using HotelMarketplace.Application.Marketplace.Dtos;
using HotelMarketplace.Application.Marketplace.Requests;
using HotelMarketplace.Domain.Entities;
using HotelMarketplace.Domain.Enums;
using HotelMarketplace.SharedKernel.Time;
using Microsoft.EntityFrameworkCore;

namespace HotelMarketplace.Infrastructure.Persistence.Marketplace;

internal sealed class EfMarketplaceBrowsingRepository : IMarketplaceBrowsingRepository
{
    private static readonly BookingStatus[] ActiveBookingStatuses =
    {
        BookingStatus.Confirmed,
        BookingStatus.CheckedIn
    };

    private static readonly RoomOperationalStatus[] UnsellableRoomStatuses =
    {
        RoomOperationalStatus.Maintenance,
        RoomOperationalStatus.OutOfService,
        RoomOperationalStatus.Blocked,
        RoomOperationalStatus.Inactive
    };

    private static readonly RoomOperationalStatus[] CurrentDayTransientUnsellableStatuses =
    {
        RoomOperationalStatus.Dirty,
        RoomOperationalStatus.Cleaning,
        RoomOperationalStatus.InspectionRequired
    };

    private static readonly AvailabilityStatus[] BlockingAvailabilityStatuses =
    {
        AvailabilityStatus.Closed,
        AvailabilityStatus.Blocked
    };

    private readonly HotelMarketplaceDbContext _dbContext;
    private readonly IDateTimeProvider _dateTimeProvider;

    public EfMarketplaceBrowsingRepository(
        HotelMarketplaceDbContext dbContext,
        IDateTimeProvider dateTimeProvider)
    {
        _dbContext = dbContext;
        _dateTimeProvider = dateTimeProvider;
    }

    public async Task<IReadOnlyCollection<HotelSearchResultDto>> SearchHotelsAsync(
        HotelSearchRequest request,
        CancellationToken cancellationToken)
    {
        DateTime utcNow = _dateTimeProvider.UtcNow;
        DateOnly today = DateOnly.FromDateTime(utcNow);

        var availableRoomTypes =
            from roomType in _dbContext.RoomTypes.IgnoreQueryFilters().AsNoTracking()
            let physicalRoomCount = _dbContext.PhysicalRooms
                .IgnoreQueryFilters()
                .AsNoTracking()
                .Count(physicalRoom => physicalRoom.RoomTypeId == roomType.Id &&
                    !UnsellableRoomStatuses.Contains(physicalRoom.Status))
            let unavailablePhysicalRoomCount = _dbContext.PhysicalRooms
                .IgnoreQueryFilters()
                .AsNoTracking()
                .Count(physicalRoom => physicalRoom.RoomTypeId == roomType.Id &&
                    !UnsellableRoomStatuses.Contains(physicalRoom.Status) &&
                    ((request.CheckInDate <= today &&
                        CurrentDayTransientUnsellableStatuses.Contains(physicalRoom.Status)) ||
                     _dbContext.RoomAvailabilities.IgnoreQueryFilters().Any(block =>
                        block.PhysicalRoomId == physicalRoom.Id &&
                        BlockingAvailabilityStatuses.Contains(block.Status) &&
                        block.StartDate < request.CheckOutDate &&
                        block.EndDate > request.CheckInDate)))
            let roomTypeFullyBlocked = _dbContext.RoomAvailabilities
                .IgnoreQueryFilters()
                .AsNoTracking()
                .Any(block => block.RoomTypeId == roomType.Id &&
                    block.PhysicalRoomId == null &&
                    BlockingAvailabilityStatuses.Contains(block.Status) &&
                    block.StartDate < request.CheckOutDate &&
                    block.EndDate > request.CheckInDate)
            let bookedRoomCount =
                (from bookingRoom in _dbContext.BookingRooms.AsNoTracking()
                 join booking in _dbContext.Bookings.IgnoreQueryFilters().AsNoTracking()
                     on bookingRoom.BookingId equals booking.Id
                 where bookingRoom.RoomTypeId == roomType.Id &&
                     (ActiveBookingStatuses.Contains(booking.Status) ||
                        (booking.Status == BookingStatus.PendingPayment &&
                            (booking.PaymentExpiresAtUtc == null || booking.PaymentExpiresAtUtc > utcNow))) &&
                     booking.CheckInDate < request.CheckOutDate &&
                     booking.CheckOutDate > request.CheckInDate
                 select (int?)bookingRoom.Quantity).Sum() ?? 0
            let availableRoomCount = physicalRoomCount - unavailablePhysicalRoomCount - bookedRoomCount
            let totalGuestCapacity = roomType.AdultCapacity + roomType.ChildCapacity
            where roomType.Status == RecordStatus.Active &&
                !roomTypeFullyBlocked &&
                availableRoomCount >= request.RoomCount &&
                (roomType.AdultCapacity + roomType.ChildCapacity) * request.RoomCount >= request.GuestCount
            select new
            {
                roomType.HotelId,
                roomType.BasePricePerNight
            };

        IQueryable<HotelProperty> hotelQuery = _dbContext.HotelProperties
            .IgnoreQueryFilters()
            .AsNoTracking()
            .Where(hotel => hotel.ApprovalStatus == HotelApprovalStatus.Approved &&
                hotel.PublicationStatus == PublicationStatus.Published);

        string? location = request.Location?.Trim();
        if (!string.IsNullOrWhiteSpace(location))
        {
            string locationPattern = $"%{EscapeLikePattern(location)}%";
            hotelQuery = hotelQuery.Where(hotel =>
                EF.Functions.Like(hotel.City, locationPattern, "\\") ||
                EF.Functions.Like(hotel.AddressLine, locationPattern, "\\") ||
                EF.Functions.Like(hotel.Name, locationPattern, "\\"));
        }

        IQueryable<HotelSearchResultDto> query =
            from hotel in hotelQuery
            join availableRoomType in availableRoomTypes on hotel.Id equals availableRoomType.HotelId
            group availableRoomType by new
            {
                hotel.Id,
                hotel.Name,
                hotel.City,
                hotel.AddressLine,
                hotel.Description
            }
            into hotelGroup
            orderby hotelGroup.Min(roomType => roomType.BasePricePerNight), hotelGroup.Key.Name
            select new HotelSearchResultDto(
                hotelGroup.Key.Id,
                hotelGroup.Key.Name,
                hotelGroup.Key.City,
                hotelGroup.Key.AddressLine,
                hotelGroup.Key.Description,
                hotelGroup.Min(roomType => roomType.BasePricePerNight),
                hotelGroup.Count());

        return await query.ToArrayAsync(cancellationToken);
    }

    public async Task<HotelDetailDto?> GetHotelDetailAsync(
        Guid hotelId,
        HotelDetailAvailabilityRequest request,
        CancellationToken cancellationToken)
    {
        HotelBaseReadModel? hotel = await _dbContext.HotelProperties
            .IgnoreQueryFilters()
            .AsNoTracking()
            .Where(hotelProperty => hotelProperty.Id == hotelId &&
                hotelProperty.ApprovalStatus == HotelApprovalStatus.Approved &&
                hotelProperty.PublicationStatus == PublicationStatus.Published)
            .Select(hotelProperty => new HotelBaseReadModel(
                hotelProperty.Id,
                hotelProperty.Name,
                hotelProperty.City,
                hotelProperty.AddressLine,
                hotelProperty.Description,
                hotelProperty.ContactEmail,
                hotelProperty.ContactPhone))
            .FirstOrDefaultAsync(cancellationToken);

        if (hotel is null)
        {
            return null;
        }

        int nights = request.CheckOutDate.DayNumber - request.CheckInDate.DayNumber;
        DateTime utcNow = _dateTimeProvider.UtcNow;
        DateOnly today = DateOnly.FromDateTime(utcNow);

        var availableRoomTypeQuery =
            from roomType in _dbContext.RoomTypes.IgnoreQueryFilters().AsNoTracking()
            let physicalRoomCount = _dbContext.PhysicalRooms
                .IgnoreQueryFilters()
                .AsNoTracking()
                .Count(physicalRoom => physicalRoom.RoomTypeId == roomType.Id &&
                    !UnsellableRoomStatuses.Contains(physicalRoom.Status))
            let unavailablePhysicalRoomCount = _dbContext.PhysicalRooms
                .IgnoreQueryFilters()
                .AsNoTracking()
                .Count(physicalRoom => physicalRoom.RoomTypeId == roomType.Id &&
                    !UnsellableRoomStatuses.Contains(physicalRoom.Status) &&
                    ((request.CheckInDate <= today &&
                        CurrentDayTransientUnsellableStatuses.Contains(physicalRoom.Status)) ||
                     _dbContext.RoomAvailabilities.IgnoreQueryFilters().Any(block =>
                        block.PhysicalRoomId == physicalRoom.Id &&
                        BlockingAvailabilityStatuses.Contains(block.Status) &&
                        block.StartDate < request.CheckOutDate &&
                        block.EndDate > request.CheckInDate)))
            let roomTypeFullyBlocked = _dbContext.RoomAvailabilities
                .IgnoreQueryFilters()
                .AsNoTracking()
                .Any(block => block.RoomTypeId == roomType.Id &&
                    block.PhysicalRoomId == null &&
                    BlockingAvailabilityStatuses.Contains(block.Status) &&
                    block.StartDate < request.CheckOutDate &&
                    block.EndDate > request.CheckInDate)
            let bookedRoomCount =
                (from bookingRoom in _dbContext.BookingRooms.AsNoTracking()
                 join booking in _dbContext.Bookings.IgnoreQueryFilters().AsNoTracking()
                     on bookingRoom.BookingId equals booking.Id
                 where bookingRoom.RoomTypeId == roomType.Id &&
                     (ActiveBookingStatuses.Contains(booking.Status) ||
                        (booking.Status == BookingStatus.PendingPayment &&
                            (booking.PaymentExpiresAtUtc == null || booking.PaymentExpiresAtUtc > utcNow))) &&
                     booking.CheckInDate < request.CheckOutDate &&
                     booking.CheckOutDate > request.CheckInDate
                 select (int?)bookingRoom.Quantity).Sum() ?? 0
            let availableRoomCount = physicalRoomCount - unavailablePhysicalRoomCount - bookedRoomCount
            let totalGuestCapacity = roomType.AdultCapacity + roomType.ChildCapacity
            where roomType.HotelId == hotelId &&
                roomType.Status == RecordStatus.Active &&
                !roomTypeFullyBlocked &&
                availableRoomCount >= request.RoomCount &&
                (roomType.AdultCapacity + roomType.ChildCapacity) * request.RoomCount >= request.GuestCount
            select new
            {
                roomType.Id,
                roomType.Name,
                roomType.AdultCapacity,
                roomType.ChildCapacity,
                TotalGuestCapacity = totalGuestCapacity,
                roomType.BasePricePerNight,
                AvailableRoomCount = availableRoomCount,
                roomType.Description
            };

        AvailableRoomTypeDto[] roomTypes = await availableRoomTypeQuery
            .OrderBy(roomType => roomType.BasePricePerNight)
            .ThenBy(roomType => roomType.Name)
            .Select(roomType => new AvailableRoomTypeDto(
                roomType.Id,
                roomType.Name,
                roomType.AdultCapacity,
                roomType.ChildCapacity,
                roomType.TotalGuestCapacity,
                roomType.BasePricePerNight,
                roomType.AvailableRoomCount,
                request.RoomCount,
                nights,
                roomType.BasePricePerNight * request.RoomCount * nights,
                roomType.Description))
            .ToArrayAsync(cancellationToken);

        return new HotelDetailDto(
            hotel.Id,
            hotel.Name,
            hotel.City,
            hotel.AddressLine,
            hotel.Description,
            hotel.ContactEmail,
            hotel.ContactPhone,
            request.CheckInDate,
            request.CheckOutDate,
            request.GuestCount,
            request.RoomCount,
            roomTypes);
    }

    private sealed record HotelBaseReadModel(
        Guid Id,
        string Name,
        string City,
        string AddressLine,
        string? Description,
        string ContactEmail,
        string ContactPhone);

    private static string EscapeLikePattern(string value)
    {
        return value
            .Replace("\\", "\\\\", StringComparison.Ordinal)
            .Replace("%", "\\%", StringComparison.Ordinal)
            .Replace("_", "\\_", StringComparison.Ordinal)
            .Replace("[", "\\[", StringComparison.Ordinal)
            .Replace("]", "\\]", StringComparison.Ordinal);
    }
}
