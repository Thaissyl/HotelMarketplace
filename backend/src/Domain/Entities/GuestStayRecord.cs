using HotelMarketplace.Domain.Common;

namespace HotelMarketplace.Domain.Entities;

public sealed class GuestStayRecord : Entity, IHotelScopedEntity
{
    private GuestStayRecord()
    {
        GuestFullName = string.Empty;
    }

    public GuestStayRecord(
        Guid id,
        Guid hotelId,
        Guid bookingId,
        Guid checkedInByUserAccountId,
        string guestFullName,
        string identityDocumentType,
        string identityDocumentNumber,
        string? identityIssuingCountry = null,
        DateOnly? identityExpiryDate = null)
        : base(id)
    {
        Guard.NotEmpty(hotelId, nameof(HotelId));
        Guard.NotEmpty(bookingId, nameof(BookingId));
        Guard.NotEmpty(checkedInByUserAccountId, nameof(CheckedInByUserAccountId));
        HotelId = hotelId;
        BookingId = bookingId;
        CheckedInByUserAccountId = checkedInByUserAccountId;
        GuestFullName = Guard.NotBlank(guestFullName, nameof(GuestFullName), 200);
        IdentityDocumentType = Guard.NotBlank(identityDocumentType, nameof(IdentityDocumentType), 32);
        IdentityDocumentNumber = Guard.NotBlank(identityDocumentNumber, nameof(IdentityDocumentNumber), 64);
        IdentityIssuingCountry = Guard.Optional(identityIssuingCountry, nameof(IdentityIssuingCountry), 2)?.ToUpperInvariant();
        IdentityExpiryDate = identityExpiryDate;
        CheckedInAtUtc = DateTime.UtcNow;
    }

    public Guid HotelId { get; private set; }

    public Guid BookingId { get; private set; }

    public Guid CheckedInByUserAccountId { get; private set; }

    public Guid? CheckedOutByUserAccountId { get; private set; }

    public string GuestFullName { get; private set; }

    public string IdentityDocumentType { get; private set; } = string.Empty;

    public string IdentityDocumentNumber { get; private set; } = string.Empty;

    public string? IdentityIssuingCountry { get; private set; }

    public DateOnly? IdentityExpiryDate { get; private set; }

    public DateTime CheckedInAtUtc { get; private set; }

    public DateTime? CheckedOutAtUtc { get; private set; }

    public void CheckOut(Guid checkedOutByUserAccountId)
    {
        Guard.NotEmpty(checkedOutByUserAccountId, nameof(CheckedOutByUserAccountId));

        if (CheckedOutAtUtc is not null)
        {
            throw new SharedKernel.Exceptions.DomainException("GuestStayRecord.AlreadyCheckedOut", "The stay record is already checked out.");
        }

        CheckedOutByUserAccountId = checkedOutByUserAccountId;
        CheckedOutAtUtc = DateTime.UtcNow;
    }
}
