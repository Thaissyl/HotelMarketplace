using HotelMarketplace.Domain.Common;
using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Domain.Entities;

public sealed class CancellationPolicy : Entity, IHotelScopedEntity
{
    private CancellationPolicy()
    {
        Name = string.Empty;
    }

    public CancellationPolicy(
        Guid id,
        Guid hotelId,
        string name,
        int freeCancellationHours,
        decimal refundPercentage,
        string? description = null)
        : base(id)
    {
        Guard.NotEmpty(hotelId, nameof(HotelId));
        Guard.Rate(refundPercentage, nameof(RefundPercentage), 100m);
        if (freeCancellationHours < 0)
        {
            throw new SharedKernel.Exceptions.DomainException("CancellationPolicy.InvalidHours", "Free cancellation hours cannot be negative.");
        }

        HotelId = hotelId;
        Name = Guard.NotBlank(name, nameof(Name), 128);
        FreeCancellationHours = freeCancellationHours;
        RefundPercentage = refundPercentage;
        Description = Guard.Optional(description, nameof(Description), 1000);
        Status = RecordStatus.Active;
    }

    public Guid HotelId { get; private set; }

    public string Name { get; private set; }

    public int FreeCancellationHours { get; private set; }

    public decimal RefundPercentage { get; private set; }

    public string? Description { get; private set; }

    public RecordStatus Status { get; private set; }

    public void Update(string name, int freeCancellationHours, decimal refundPercentage, string? description)
    {
        Guard.Rate(refundPercentage, nameof(RefundPercentage), 100m);
        if (freeCancellationHours < 0)
        {
            throw new SharedKernel.Exceptions.DomainException("CancellationPolicy.InvalidHours", "Free cancellation hours cannot be negative.");
        }

        Name = Guard.NotBlank(name, nameof(Name), 128);
        FreeCancellationHours = freeCancellationHours;
        RefundPercentage = refundPercentage;
        Description = Guard.Optional(description, nameof(Description), 1000);
        Status = RecordStatus.Active;
    }
}
