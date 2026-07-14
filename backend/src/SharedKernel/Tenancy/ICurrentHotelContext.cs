namespace HotelMarketplace.SharedKernel.Tenancy;

public interface ICurrentHotelContext
{
    Guid? HotelId { get; }

    bool IsHotelScopeEnforced { get; }
}
