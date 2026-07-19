using HotelMarketplace.Domain.Common;

namespace HotelMarketplace.Domain.Entities;

public sealed class SavedHotel : Entity
{
    private SavedHotel()
    {
    }

    public SavedHotel(Guid id, Guid userAccountId, Guid hotelId, DateTime createdAtUtc)
        : base(id)
    {
        Guard.NotEmpty(userAccountId, nameof(UserAccountId));
        Guard.NotEmpty(hotelId, nameof(HotelId));
        UserAccountId = userAccountId;
        HotelId = hotelId;
        CreatedAtUtc = createdAtUtc.Kind == DateTimeKind.Local
            ? throw new SharedKernel.Exceptions.DomainException(
                "SavedHotel.InvalidCreatedTime",
                "Saved hotel creation time must be expressed in UTC.")
            : DateTime.SpecifyKind(createdAtUtc, DateTimeKind.Utc);
    }

    public Guid UserAccountId { get; private set; }
    public Guid HotelId { get; private set; }
    public DateTime CreatedAtUtc { get; private set; }
}
