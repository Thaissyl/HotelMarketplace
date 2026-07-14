namespace HotelMarketplace.Domain.Security;

public static class SeededRoleIds
{
    public static readonly Guid Customer = Guid.Parse("11111111-1111-1111-1111-111111111001");
    public static readonly Guid PropertyOwner = Guid.Parse("11111111-1111-1111-1111-111111111002");
    public static readonly Guid HotelManager = Guid.Parse("11111111-1111-1111-1111-111111111003");
    public static readonly Guid Receptionist = Guid.Parse("11111111-1111-1111-1111-111111111004");
    public static readonly Guid HousekeepingStaff = Guid.Parse("11111111-1111-1111-1111-111111111005");
    public static readonly Guid MaintenanceStaff = Guid.Parse("11111111-1111-1111-1111-111111111006");
    public static readonly Guid PlatformAdministrator = Guid.Parse("11111111-1111-1111-1111-111111111007");
}
