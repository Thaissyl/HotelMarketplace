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
        string guestFullName,
        string guestPhone)
        : base(id)
    {
        Guard.NotEmpty(customerUserAccountId, nameof(CustomerUserAccountId));
        Guard.NotEmpty(hotelId, nameof(HotelId));
        Guard.DateRange(checkInDate, checkOutDate, "Booking.InvalidStayDates");
        Guard.NonNegative(totalAmount, nameof(TotalAmount));
        BookingCode = Guard.NotBlank(bookingCode, nameof(BookingCode), 32).ToUpperInvariant();
        CustomerUserAccountId = customerUserAccountId;
        HotelId = hotelId;
        CheckInDate = checkInDate;
        CheckOutDate = checkOutDate;
        PaymentMode = paymentMode;
        Source = source;
        TotalAmount = totalAmount;
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

    public string GuestFullName { get; private set; }

    public string GuestPhone { get; private set; }

    public DateTime CreatedAtUtc { get; private set; }

    public DateTime? PaymentExpiresAtUtc { get; private set; }

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
}
