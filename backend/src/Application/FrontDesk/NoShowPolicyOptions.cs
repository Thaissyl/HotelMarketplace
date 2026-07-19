namespace HotelMarketplace.Application.FrontDesk;

public sealed record NoShowPolicyOptions(int EligibleAfterHours)
{
    public const int DefaultEligibleAfterHours = 24;
}
