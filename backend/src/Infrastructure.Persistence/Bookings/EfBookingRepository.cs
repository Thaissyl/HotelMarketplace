using System.Data;
using System.Data.Common;
using System.Globalization;
using HotelMarketplace.Application.Bookings;
using HotelMarketplace.Application.Bookings.Dtos;
using HotelMarketplace.Domain.Entities;
using HotelMarketplace.Domain.Enums;
using HotelMarketplace.SharedKernel.Time;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;

namespace HotelMarketplace.Infrastructure.Persistence.Bookings;

internal sealed class EfBookingRepository : IBookingRepository
{
    private static readonly BookingStatus[] BlockingConfirmedStatuses =
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

    private readonly HotelMarketplaceDbContext _dbContext;
    private readonly IDateTimeProvider _dateTimeProvider;

    public EfBookingRepository(
        HotelMarketplaceDbContext dbContext,
        IDateTimeProvider dateTimeProvider)
    {
        _dbContext = dbContext;
        _dateTimeProvider = dateTimeProvider;
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

            int lockResult = await AcquireReservationLockAsync(request, cancellationToken);
            if (lockResult < 0)
            {
                await transaction.RollbackAsync(cancellationToken);
                return CreateBookingRepositoryResult.Failure(CreateBookingRepositoryStatus.ReservationLockUnavailable);
            }

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

            int physicalRoomCount = await _dbContext.PhysicalRooms
                .IgnoreQueryFilters()
                .AsNoTracking()
                .CountAsync(physicalRoom => physicalRoom.HotelId == request.HotelId &&
                    physicalRoom.RoomTypeId == request.RoomTypeId &&
                    !UnsellableRoomStatuses.Contains(physicalRoom.Status),
                    cancellationToken);

            int reservedRoomCount = await (
                from bookingRoom in _dbContext.BookingRooms.AsNoTracking()
                join existingBooking in _dbContext.Bookings.IgnoreQueryFilters().AsNoTracking()
                    on bookingRoom.BookingId equals existingBooking.Id
                where existingBooking.HotelId == request.HotelId &&
                    bookingRoom.RoomTypeId == request.RoomTypeId &&
                    existingBooking.CheckInDate < request.CheckOutDate &&
                    existingBooking.CheckOutDate > request.CheckInDate &&
                    (BlockingConfirmedStatuses.Contains(existingBooking.Status) ||
                        (existingBooking.Status == BookingStatus.PendingPayment &&
                            (existingBooking.PaymentExpiresAtUtc == null || existingBooking.PaymentExpiresAtUtc > utcNow)))
                select (int?)bookingRoom.Quantity)
                .SumAsync(cancellationToken) ?? 0;

            int availableRoomCount = physicalRoomCount - reservedRoomCount;
            if (availableRoomCount < request.RoomCount)
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

    private async Task<int> AcquireReservationLockAsync(
        CreateBookingRepositoryRequest request,
        CancellationToken cancellationToken)
    {
        DbConnection connection = _dbContext.Database.GetDbConnection();
        await using DbCommand command = connection.CreateCommand();
        command.Transaction = _dbContext.Database.CurrentTransaction?.GetDbTransaction();
        command.CommandText = """
            DECLARE @lockResult int;
            EXEC @lockResult = sys.sp_getapplock
                @Resource = @resource,
                @LockMode = 'Exclusive',
                @LockOwner = 'Transaction',
                @LockTimeout = @lockTimeout;
            SELECT @lockResult;
            """;

        DbParameter resourceParameter = command.CreateParameter();
        resourceParameter.ParameterName = "@resource";
        resourceParameter.DbType = DbType.String;
        resourceParameter.Value = $"booking:{request.HotelId:N}:{request.RoomTypeId:N}:{request.CheckInDate:yyyyMMdd}:{request.CheckOutDate:yyyyMMdd}";
        command.Parameters.Add(resourceParameter);

        DbParameter timeoutParameter = command.CreateParameter();
        timeoutParameter.ParameterName = "@lockTimeout";
        timeoutParameter.DbType = DbType.Int32;
        timeoutParameter.Value = 10_000;
        command.Parameters.Add(timeoutParameter);

        object? result = await command.ExecuteScalarAsync(cancellationToken);
        return Convert.ToInt32(result, CultureInfo.InvariantCulture);
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
}
