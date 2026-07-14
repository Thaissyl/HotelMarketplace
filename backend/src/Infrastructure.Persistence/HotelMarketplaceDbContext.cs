using System.Linq.Expressions;
using HotelMarketplace.Domain.Common;
using HotelMarketplace.Domain.Entities;
using HotelMarketplace.SharedKernel.Tenancy;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata;

namespace HotelMarketplace.Infrastructure.Persistence;

public sealed class HotelMarketplaceDbContext : DbContext
{
    private readonly ICurrentHotelContext _currentHotelContext;

    public HotelMarketplaceDbContext(
        DbContextOptions<HotelMarketplaceDbContext> options,
        ICurrentHotelContext currentHotelContext)
        : base(options)
    {
        _currentHotelContext = currentHotelContext;
    }

    public Guid? CurrentHotelId => _currentHotelContext.HotelId;

    public bool IsHotelScopeEnforced => _currentHotelContext.IsHotelScopeEnforced;

    public DbSet<UserAccount> UserAccounts => Set<UserAccount>();

    public DbSet<UserRole> UserRoles => Set<UserRole>();

    public DbSet<UserAccountRole> UserAccountRoles => Set<UserAccountRole>();

    public DbSet<HotelStaffAssignment> HotelStaffAssignments => Set<HotelStaffAssignment>();

    public DbSet<StaffInvitation> StaffInvitations => Set<StaffInvitation>();

    public DbSet<HotelProperty> HotelProperties => Set<HotelProperty>();

    public DbSet<HotelImage> HotelImages => Set<HotelImage>();

    public DbSet<Amenity> Amenities => Set<Amenity>();

    public DbSet<HotelAmenity> HotelAmenities => Set<HotelAmenity>();

    public DbSet<CancellationPolicy> CancellationPolicies => Set<CancellationPolicy>();

    public DbSet<RoomType> RoomTypes => Set<RoomType>();

    public DbSet<PhysicalRoom> PhysicalRooms => Set<PhysicalRoom>();

    public DbSet<RoomAvailability> RoomAvailabilities => Set<RoomAvailability>();

    public DbSet<Booking> Bookings => Set<Booking>();

    public DbSet<BookingRoom> BookingRooms => Set<BookingRoom>();

    public DbSet<BookingRoomAssignment> BookingRoomAssignments => Set<BookingRoomAssignment>();

    public DbSet<PaymentTransaction> PaymentTransactions => Set<PaymentTransaction>();

    public DbSet<PaymentCollectionRecord> PaymentCollectionRecords => Set<PaymentCollectionRecord>();

    public DbSet<RefundRecord> RefundRecords => Set<RefundRecord>();

    public DbSet<Invoice> Invoices => Set<Invoice>();

    public DbSet<CommissionRecord> CommissionRecords => Set<CommissionRecord>();

    public DbSet<SettlementRecord> SettlementRecords => Set<SettlementRecord>();

    public DbSet<SettlementItem> SettlementItems => Set<SettlementItem>();

    public DbSet<NotificationRecord> NotificationRecords => Set<NotificationRecord>();

    public DbSet<AuditRecord> AuditRecords => Set<AuditRecord>();

    public DbSet<HousekeepingTask> HousekeepingTasks => Set<HousekeepingTask>();

    public DbSet<MaintenanceRequest> MaintenanceRequests => Set<MaintenanceRequest>();

    public DbSet<RoomStatusHistory> RoomStatusHistories => Set<RoomStatusHistory>();

    public DbSet<GuestStayRecord> GuestStayRecords => Set<GuestStayRecord>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.ApplyConfigurationsFromAssembly(typeof(HotelMarketplaceDbContext).Assembly);
        ApplyHotelQueryFilters(modelBuilder);
    }

    private void ApplyHotelQueryFilters(ModelBuilder modelBuilder)
    {
        foreach (IMutableEntityType entityType in modelBuilder.Model.GetEntityTypes())
        {
            Type clrType = entityType.ClrType;

            if (typeof(IHotelScopedEntity).IsAssignableFrom(clrType))
            {
                string hotelPropertyName = clrType == typeof(HotelProperty) ? nameof(Entity.Id) : "HotelId";
                entityType.SetQueryFilter(CreateRequiredHotelFilter(clrType, hotelPropertyName));
                continue;
            }

            IMutableProperty? hotelIdProperty = entityType.FindProperty("HotelId");

            if (hotelIdProperty?.ClrType == typeof(Guid?))
            {
                entityType.SetQueryFilter(CreateOptionalHotelFilter(clrType));
            }
        }
    }

    private LambdaExpression CreateRequiredHotelFilter(Type entityType, string hotelPropertyName)
    {
        ParameterExpression parameter = Expression.Parameter(entityType, "entity");
        MethodCallExpression hotelId = Expression.Call(
            typeof(EF),
            nameof(EF.Property),
            new[] { typeof(Guid) },
            parameter,
            Expression.Constant(hotelPropertyName));

        UnaryExpression nullableHotelId = Expression.Convert(hotelId, typeof(Guid?));

        BinaryExpression tenantMatch = Expression.Equal(
            nullableHotelId,
            Expression.Property(Expression.Constant(this), nameof(CurrentHotelId)));

        BinaryExpression filterDisabled = Expression.Equal(
            Expression.Property(Expression.Constant(this), nameof(IsHotelScopeEnforced)),
            Expression.Constant(false));

        return Expression.Lambda(Expression.OrElse(filterDisabled, tenantMatch), parameter);
    }

    private LambdaExpression CreateOptionalHotelFilter(Type entityType)
    {
        ParameterExpression parameter = Expression.Parameter(entityType, "entity");
        MethodCallExpression hotelId = Expression.Call(
            typeof(EF),
            nameof(EF.Property),
            new[] { typeof(Guid?) },
            parameter,
            Expression.Constant("HotelId"));

        BinaryExpression tenantMatch = Expression.Equal(
            hotelId,
            Expression.Property(Expression.Constant(this), nameof(CurrentHotelId)));

        BinaryExpression unscopedRecord = Expression.Equal(hotelId, Expression.Constant(null, typeof(Guid?)));

        BinaryExpression filterDisabled = Expression.Equal(
            Expression.Property(Expression.Constant(this), nameof(IsHotelScopeEnforced)),
            Expression.Constant(false));

        return Expression.Lambda(Expression.OrElse(filterDisabled, Expression.OrElse(unscopedRecord, tenantMatch)), parameter);
    }
}
