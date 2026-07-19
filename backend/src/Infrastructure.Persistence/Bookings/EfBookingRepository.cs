using System.Data;
using System.Globalization;
using HotelMarketplace.Application.Bookings;
using HotelMarketplace.Application.Bookings.Dtos;
using HotelMarketplace.Application.Inventory;
using HotelMarketplace.Domain.Entities;
using HotelMarketplace.Domain.Enums;
using HotelMarketplace.SharedKernel.Time;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;

namespace HotelMarketplace.Infrastructure.Persistence.Bookings;

internal sealed class EfBookingRepository : IBookingRepository
{
    private readonly HotelMarketplaceDbContext _dbContext;
    private readonly IDateTimeProvider _dateTimeProvider;
    private readonly IInventoryCommitmentCoordinator _inventoryCommitmentCoordinator;

    public EfBookingRepository(
        HotelMarketplaceDbContext dbContext,
        IDateTimeProvider dateTimeProvider,
        IInventoryCommitmentCoordinator inventoryCommitmentCoordinator)
    {
        _dbContext = dbContext;
        _dateTimeProvider = dateTimeProvider;
        _inventoryCommitmentCoordinator = inventoryCommitmentCoordinator;
    }

    public async Task<CreateBookingRepositoryResult> CreatePendingBookingAsync(
        CreateBookingRepositoryRequest request,
        CancellationToken cancellationToken)
    {
        Microsoft.EntityFrameworkCore.Storage.IExecutionStrategy executionStrategy = _dbContext.Database.CreateExecutionStrategy();

        return await executionStrategy.ExecuteAsync(async () =>
        {
            await using IDbContextTransaction transaction = await _dbContext.Database.BeginTransactionAsync(
                IsolationLevel.Serializable,
                cancellationToken);

            DateTime utcNow = _dateTimeProvider.UtcNow;
            DateTime paymentExpiresAtUtc = utcNow.AddMinutes(15);

            bool hotelIsBookable = await _dbContext.HotelProperties
                .IgnoreQueryFilters()
                .AsNoTracking()
                .AnyAsync(hotel => hotel.Id == request.HotelId &&
                    hotel.ApprovalStatus == HotelApprovalStatus.Approved &&
                    hotel.PublicationStatus == PublicationStatus.Published,
                    cancellationToken);

            if (!hotelIsBookable)
            {
                await transaction.RollbackAsync(cancellationToken);
                return CreateBookingRepositoryResult.Failure(CreateBookingRepositoryStatus.HotelNotAvailable);
            }

            RoomTypeBookingReadModel? roomType = await _dbContext.RoomTypes
                .IgnoreQueryFilters()
                .AsNoTracking()
                .Where(roomType => roomType.Id == request.RoomTypeId &&
                    roomType.HotelId == request.HotelId &&
                    roomType.Status == RecordStatus.Active)
                .Select(roomType => new RoomTypeBookingReadModel(
                    roomType.Id,
                    roomType.HotelId,
                    roomType.AdultCapacity,
                    roomType.ChildCapacity,
                    roomType.BasePricePerNight))
                .FirstOrDefaultAsync(cancellationToken);

            if (roomType is null)
            {
                await transaction.RollbackAsync(cancellationToken);
                return CreateBookingRepositoryResult.Failure(CreateBookingRepositoryStatus.RoomTypeNotAvailable);
            }

            if ((roomType.AdultCapacity + roomType.ChildCapacity) * request.RoomCount < request.GuestCount)
            {
                await transaction.RollbackAsync(cancellationToken);
                return CreateBookingRepositoryResult.Failure(CreateBookingRepositoryStatus.CapacityExceeded);
            }

            InventoryCommitmentEvaluation inventory = await _inventoryCommitmentCoordinator.AcquireAndEvaluateAsync(
                request.HotelId,
                request.RoomTypeId,
                request.CheckInDate,
                request.CheckOutDate,
                request.RoomCount,
                utcNow,
                ignoredBookingId: null,
                cancellationToken);

            if (inventory.Status == InventoryCommitmentStatus.LockUnavailable)
            {
                await transaction.RollbackAsync(cancellationToken);
                return CreateBookingRepositoryResult.Failure(CreateBookingRepositoryStatus.ReservationLockUnavailable);
            }

            if (inventory.Status == InventoryCommitmentStatus.InsufficientAvailability)
            {
                await transaction.RollbackAsync(cancellationToken);
                return CreateBookingRepositoryResult.Failure(CreateBookingRepositoryStatus.InsufficientAvailability);
            }

            int nights = request.CheckOutDate.DayNumber - request.CheckInDate.DayNumber;
            decimal totalAmount = request.RoomCount * nights * roomType.BasePricePerNight;
            Guid bookingId = Guid.NewGuid();
            string bookingCode = GenerateBookingCode(utcNow);

            Booking booking = new(
                bookingId,
                bookingCode,
                request.CustomerUserAccountId,
                request.HotelId,
                request.CheckInDate,
                request.CheckOutDate,
                PaymentMode.PlatformCollect,
                BookingSource.Marketplace,
                totalAmount,
                request.GuestFullName,
                request.GuestPhone);

            booking.SetPaymentExpiration(paymentExpiresAtUtc);
            booking.AddRoom(new BookingRoom(
                Guid.NewGuid(),
                bookingId,
                request.RoomTypeId,
                request.RoomCount,
                roomType.BasePricePerNight,
                nights));

            await _dbContext.Bookings.AddAsync(booking, cancellationToken);
            await _dbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);

            BookingDto bookingDto = new(
                booking.Id,
                booking.BookingCode,
                booking.HotelId,
                request.RoomTypeId,
                booking.CheckInDate,
                booking.CheckOutDate,
                request.RoomCount,
                request.GuestCount,
                nights,
                roomType.BasePricePerNight,
                booking.TotalAmount,
                booking.Status,
                booking.CreatedAtUtc,
                booking.PaymentExpiresAtUtc,
                booking.GuestFullName,
                booking.GuestPhone);

            return CreateBookingRepositoryResult.Success(bookingDto);
        });
    }

    public async Task<IReadOnlyCollection<BookingDto>> GetBookingsForCustomerAsync(
        Guid customerUserAccountId,
        CancellationToken cancellationToken)
    {
        List<BookingReadModel> rows = await (
            from booking in _dbContext.Bookings.IgnoreQueryFilters().AsNoTracking()
            join bookingRoom in _dbContext.BookingRooms.IgnoreQueryFilters().AsNoTracking()
                on booking.Id equals bookingRoom.BookingId
            where booking.CustomerUserAccountId == customerUserAccountId
            orderby booking.CreatedAtUtc descending
            select new BookingReadModel(
                booking.Id,
                booking.BookingCode,
                booking.HotelId,
                bookingRoom.RoomTypeId,
                booking.CheckInDate,
                booking.CheckOutDate,
                bookingRoom.Quantity,
                bookingRoom.Nights,
                bookingRoom.UnitPricePerNight,
                booking.TotalAmount,
                booking.Status,
                booking.CreatedAtUtc,
                booking.PaymentExpiresAtUtc,
                booking.GuestFullName,
                booking.GuestPhone))
            .ToListAsync(cancellationToken);

        return rows
            .Select(row => new BookingDto(
                row.Id,
                row.BookingCode,
                row.HotelId,
                row.RoomTypeId,
                row.CheckInDate,
                row.CheckOutDate,
                row.RoomCount,
                1,
                row.Nights,
                row.UnitPricePerNight,
                row.TotalAmount,
                row.Status,
                row.CreatedAtUtc,
                row.PaymentExpiresAtUtc,
                row.GuestFullName,
                row.GuestPhone))
            .ToArray();
    }

    private static string GenerateBookingCode(DateTime utcNow)
    {
        string suffix = Guid.NewGuid().ToString("N", CultureInfo.InvariantCulture)[..10].ToUpperInvariant();
        return $"BK{utcNow.ToString("yyyyMMddHHmmss", CultureInfo.InvariantCulture)}{suffix}";
    }

    private sealed record RoomTypeBookingReadModel(
        Guid Id,
        Guid HotelId,
        int AdultCapacity,
        int ChildCapacity,
        decimal BasePricePerNight);

    private sealed record BookingReadModel(
        Guid Id,
        string BookingCode,
        Guid HotelId,
        Guid RoomTypeId,
        DateOnly CheckInDate,
        DateOnly CheckOutDate,
        int RoomCount,
        int Nights,
        decimal UnitPricePerNight,
        decimal TotalAmount,
        BookingStatus Status,
        DateTime CreatedAtUtc,
        DateTime? PaymentExpiresAtUtc,
        string GuestFullName,
        string GuestPhone);
}
