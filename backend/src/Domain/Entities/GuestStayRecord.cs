using HotelMarketplace.Domain.Common;

namespace HotelMarketplace.Domain.Entities;

public sealed class GuestStayRecord : Entity, IHotelScopedEntity
{
    private GuestStayRecord()
    {
        GuestFullName = string.Empty;
    }

    public GuestStayRecord(Guid id, Guid hotelId, Guid bookingId, Guid checkedInByUserAccountId, string guestFullName, string? identityDocumentNumber = null)
        : base(id)
    {
        Guard.NotEmpty(hotelId, nameof(HotelId));
        Guard.NotEmpty(bookingId, nameof(BookingId));
        Guard.NotEmpty(checkedInByUserAccountId, nameof(CheckedInByUserAccountId));
        HotelId = hotelId;
        BookingId = bookingId;
        CheckedInByUserAccountId = checkedInByUserAccountId;
        GuestFullName = Guard.NotBlank(guestFullName, nameof(GuestFullName), 200);
        IdentityDocumentNumber = Guard.Optional(identityDocumentNumber, nameof(IdentityDocumentNumber), 64);
        CheckedInAtUtc = DateTime.UtcNow;
    }

    public Guid HotelId { get; private set; }

    public Guid BookingId { get; private set; }

    public Guid CheckedInByUserAccountId { get; private set; }

    public Guid? CheckedOutByUserAccountId { get; private set; }

    public string GuestFullName { get; private set; }

    public string? IdentityDocumentNumber { get; private set; }

    public DateTime CheckedInAtUtc { get; private set; }

    public DateTime? CheckedOutAtUtc { get; private set; }
}
