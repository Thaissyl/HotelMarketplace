using HotelMarketplace.Domain.Common;
using HotelMarketplace.Domain.Enums;
using HotelMarketplace.SharedKernel.Exceptions;

namespace HotelMarketplace.Domain.Entities;

public sealed class Booking : Entity, IHotelScopedEntity
{
    private readonly List<BookingRoom> _rooms = new();

    private Booking()
    {
        BookingCode = string.Empty;
        GuestFullName = string.Empty;
        GuestPhone = string.Empty;
    }

    public Booking(
        Guid id,
        string bookingCode,
        Guid customerUserAccountId,
        Guid hotelId,
        DateOnly checkInDate,
        DateOnly checkOutDate,
        PaymentMode paymentMode,
        BookingSource source,
        decimal totalAmount,
        int guestCount,
        string guestFullName,
        string guestPhone)
        : base(id)
    {
        Guard.NotEmpty(customerUserAccountId, nameof(CustomerUserAccountId));
        Guard.NotEmpty(hotelId, nameof(HotelId));
        Guard.DateRange(checkInDate, checkOutDate, "Booking.InvalidStayDates");
        Guard.NonNegative(totalAmount, nameof(TotalAmount));
        Guard.GreaterThanZero(guestCount, nameof(GuestCount));
        BookingCode = Guard.NotBlank(bookingCode, nameof(BookingCode), 32).ToUpperInvariant();
        CustomerUserAccountId = customerUserAccountId;
        HotelId = hotelId;
        CheckInDate = checkInDate;
        CheckOutDate = checkOutDate;
        PaymentMode = paymentMode;
        Source = source;
        TotalAmount = totalAmount;
        GuestCount = guestCount;
        GuestFullName = Guard.NotBlank(guestFullName, nameof(GuestFullName), 200);
        GuestPhone = Guard.NotBlank(guestPhone, nameof(GuestPhone), 32);
        Status = paymentMode == PaymentMode.PlatformCollect ? BookingStatus.PendingPayment : BookingStatus.Confirmed;
        CreatedAtUtc = DateTime.UtcNow;
    }

    public string BookingCode { get; private set; }

    public Guid CustomerUserAccountId { get; private set; }

    public Guid HotelId { get; private set; }

    public DateOnly CheckInDate { get; private set; }

    public DateOnly CheckOutDate { get; private set; }

    public PaymentMode PaymentMode { get; private set; }

    public BookingSource Source { get; private set; }

    public BookingStatus Status { get; private set; }

    public decimal TotalAmount { get; private set; }

    public int GuestCount { get; private set; }

    public string GuestFullName { get; private set; }

    public string GuestPhone { get; private set; }

    public DateTime CreatedAtUtc { get; private set; }

    public DateTime? PaymentExpiresAtUtc { get; private set; }

    public string? CancellationReason { get; private set; }

    public DateTime? CancelledAtUtc { get; private set; }

    public string? NoShowReason { get; private set; }

    public DateTime? NoShowAtUtc { get; private set; }

    public string? CancellationPolicyName { get; private set; }

    public int? CancellationPolicyFreeCancellationHours { get; private set; }

    public decimal? CancellationPolicyRefundPercentage { get; private set; }

    public IReadOnlyCollection<BookingRoom> Rooms => _rooms;

    public void AddRoom(BookingRoom bookingRoom)
    {
        if (bookingRoom.BookingId != Id)
        {
            throw new DomainException("Booking.InvalidBookingRoom", "Booking room must belong to the booking.");
        }

        if (_rooms.Count > 0)
        {
            throw new DomainException("Booking.MultipleRoomTypesNotSupported", "A booking can contain only one room type in this version.");
        }

        _rooms.Add(bookingRoom);
    }

    public void SetPaymentExpiration(DateTime expiresAtUtc)
    {
        if (expiresAtUtc <= CreatedAtUtc)
        {
            throw new DomainException("Booking.InvalidPaymentExpiration", "Payment expiration must be after booking creation time.");
        }

        PaymentExpiresAtUtc = expiresAtUtc;
    }

    public void ApplyCancellationPolicySnapshot(CancellationPolicy policy)
    {
        if (policy.HotelId != HotelId)
        {
            throw new DomainException(
                "Booking.InvalidCancellationPolicy",
                "Cancellation policy must belong to the booking hotel.");
        }

        CancellationPolicyName = policy.Name;
        CancellationPolicyFreeCancellationHours = policy.FreeCancellationHours;
        CancellationPolicyRefundPercentage = policy.RefundPercentage;
    }

    public void ConfirmPayment()
    {
        if (Status == BookingStatus.Confirmed)
        {
            return;
        }

        if (Status != BookingStatus.PendingPayment)
        {
            throw new DomainException("Booking.InvalidStatusForConfirmation", "Only pending payment bookings can be confirmed.");
        }

        Status = BookingStatus.Confirmed;
    }

    public void CheckIn()
    {
        if (Status != BookingStatus.Confirmed)
        {
            throw new DomainException("Booking.InvalidStatusForCheckIn", "Only confirmed bookings can be checked in.");
        }

        Status = BookingStatus.CheckedIn;
    }

    public void CheckOut()
    {
        if (Status != BookingStatus.CheckedIn)
        {
            throw new DomainException("Booking.InvalidStatusForCheckOut", "Only checked-in bookings can be checked out.");
        }

        Status = BookingStatus.CheckedOut;
    }

    public void ExpirePaymentHold(DateTime utcNow)
    {
        if (Status != BookingStatus.PendingPayment)
        {
            return;
        }

        if (PaymentExpiresAtUtc is null || PaymentExpiresAtUtc > utcNow)
        {
            throw new DomainException("Booking.PaymentHoldStillValid", "The payment hold has not expired.");
        }

        Status = BookingStatus.Expired;
    }

    public void Cancel(string reason, DateTime utcNow)
    {
        if (Status is not (BookingStatus.PendingPayment or BookingStatus.Confirmed))
        {
            throw new DomainException(
                "Booking.InvalidStatusForCancellation",
                "Only pending payment or confirmed bookings can be cancelled.");
        }

        CancellationReason = Guard.NotBlank(reason, nameof(CancellationReason), 500);
        CancelledAtUtc = EnsureUtc(utcNow, nameof(utcNow));
        PaymentExpiresAtUtc = null;
        Status = BookingStatus.Cancelled;
    }

    public void MarkNoShow(string reason, DateTime utcNow)
    {
        if (Status != BookingStatus.Confirmed)
        {
            throw new DomainException(
                "Booking.InvalidStatusForNoShow",
                "Only confirmed bookings can be marked as no-show.");
        }

        NoShowReason = Guard.NotBlank(reason, nameof(NoShowReason), 500);
        NoShowAtUtc = EnsureUtc(utcNow, nameof(utcNow));
        Status = BookingStatus.NoShow;
    }

    private static DateTime EnsureUtc(DateTime value, string parameterName)
    {
        if (value.Kind == DateTimeKind.Local)
        {
            throw new DomainException(
                "Booking.InvalidUtcTimestamp",
                $"{parameterName} must be expressed in UTC.");
        }

        return DateTime.SpecifyKind(value, DateTimeKind.Utc);
    }
}
