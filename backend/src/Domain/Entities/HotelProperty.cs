using HotelMarketplace.Domain.Common;
using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Domain.Entities;

public sealed class HotelProperty : Entity, IHotelScopedEntity
{
    private readonly List<HotelImage> _images = new();
    private readonly List<HotelAmenity> _amenities = new();
    private readonly List<RoomType> _roomTypes = new();
    private readonly List<PhysicalRoom> _physicalRooms = new();

    private HotelProperty()
    {
        Name = string.Empty;
        City = string.Empty;
        AddressLine = string.Empty;
        ContactEmail = string.Empty;
        ContactPhone = string.Empty;
    }

    public HotelProperty(
        Guid id,
        Guid ownerUserAccountId,
        string name,
        string city,
        string addressLine,
        string contactEmail,
        string contactPhone,
        string? description = null)
        : base(id)
    {
        Guard.NotEmpty(ownerUserAccountId, nameof(OwnerUserAccountId));
        OwnerUserAccountId = ownerUserAccountId;
        Name = Guard.NotBlank(name, nameof(Name), 200);
        City = Guard.NotBlank(city, nameof(City), 100);
        AddressLine = Guard.NotBlank(addressLine, nameof(AddressLine), 300);
        ContactEmail = Guard.NotBlank(contactEmail, nameof(ContactEmail), 256).ToLowerInvariant();
        ContactPhone = Guard.NotBlank(contactPhone, nameof(ContactPhone), 32);
        Description = Guard.Optional(description, nameof(Description), 2000);
        ApprovalStatus = HotelApprovalStatus.PendingReview;
        PublicationStatus = PublicationStatus.Unpublished;
        DefaultCommissionRate = 0.10m;
        IsWalkInEnabled = true;
        CreatedAtUtc = DateTime.UtcNow;
    }

    public Guid HotelId => Id;

    public Guid OwnerUserAccountId { get; private set; }

    public string Name { get; private set; }

    public string City { get; private set; }

    public string AddressLine { get; private set; }

    public string ContactEmail { get; private set; }

    public string ContactPhone { get; private set; }

    public string? Description { get; private set; }

    public HotelApprovalStatus ApprovalStatus { get; private set; }

    public PublicationStatus PublicationStatus { get; private set; }

    public decimal DefaultCommissionRate { get; private set; }

    public bool IsWalkInEnabled { get; private set; }

    public DateTime CreatedAtUtc { get; private set; }

    public IReadOnlyCollection<HotelImage> Images => _images;

    public IReadOnlyCollection<HotelAmenity> Amenities => _amenities;

    public IReadOnlyCollection<RoomType> RoomTypes => _roomTypes;

    public IReadOnlyCollection<PhysicalRoom> PhysicalRooms => _physicalRooms;

    public void UpdateProfile(
        string name,
        string city,
        string addressLine,
        string contactEmail,
        string contactPhone,
        string? description)
    {
        Name = Guard.NotBlank(name, nameof(Name), 200);
        City = Guard.NotBlank(city, nameof(City), 100);
        AddressLine = Guard.NotBlank(addressLine, nameof(AddressLine), 300);
        ContactEmail = Guard.NotBlank(contactEmail, nameof(ContactEmail), 256).ToLowerInvariant();
        ContactPhone = Guard.NotBlank(contactPhone, nameof(ContactPhone), 32);
        Description = Guard.Optional(description, nameof(Description), 2000);

        if (ApprovalStatus == HotelApprovalStatus.Approved)
        {
            ApprovalStatus = HotelApprovalStatus.PendingReview;
            PublicationStatus = PublicationStatus.Unpublished;
        }
    }

    public void Approve()
    {
        if (ApprovalStatus != HotelApprovalStatus.PendingReview)
        {
            throw new SharedKernel.Exceptions.DomainException("HotelProperty.InvalidApprovalStatus", "Only hotels pending review can be approved.");
        }

        ApprovalStatus = HotelApprovalStatus.Approved;
        PublicationStatus = PublicationStatus.Published;
    }

    public void Reject()
    {
        if (ApprovalStatus != HotelApprovalStatus.PendingReview)
        {
            throw new SharedKernel.Exceptions.DomainException("HotelProperty.InvalidRejectionStatus", "Only hotels pending review can be rejected.");
        }

        ApprovalStatus = HotelApprovalStatus.Rejected;
        PublicationStatus = PublicationStatus.Unpublished;
    }

    public void UpdateCommissionRate(decimal commissionRate)
    {
        Guard.Rate(commissionRate, nameof(DefaultCommissionRate), 0.30m);
        DefaultCommissionRate = commissionRate;
    }
}
