namespace HotelMarketplace.SharedKernel.Time;

public interface IDateTimeProvider
{
    DateTime UtcNow { get; }

    DateOnly Today { get; }
}
