using System.Linq.Expressions;
using HotelMarketplace.Application.Security;
using HotelMarketplace.Domain.Common;
using HotelMarketplace.Domain.Entities;
using HotelMarketplace.Domain.Enums;
using HotelMarketplace.SharedKernel.Tenancy;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata;

namespace HotelMarketplace.Infrastructure.Persistence;

public sealed class HotelMarketplaceDbContext : DbContext
{
    private readonly ICurrentHotelContext _currentHotelContext;
    private readonly ICurrentUserService _currentUserService;

    private static readonly HashSet<Type> AuditedEntityTypes =
    [
        typeof(UserAccount),
        typeof(HotelStaffAssignment),
        typeof(HotelProperty),
        typeof(RoomType),
        typeof(PhysicalRoom),
        typeof(RoomAvailability),
        typeof(Booking),
        typeof(BookingRoomAssignment),
        typeof(PaymentTransaction),
        typeof(PaymentCollectionRecord),
        typeof(RefundRecord),
        typeof(Invoice),
        typeof(CommissionRecord),
        typeof(SettlementRecord),
        typeof(HousekeepingTask),
        typeof(MaintenanceRequest),
        typeof(GuestStayRecord)
    ];

    public HotelMarketplaceDbContext(
        DbContextOptions<HotelMarketplaceDbContext> options,
        ICurrentHotelContext currentHotelContext,
        ICurrentUserService currentUserService)
        : base(options)
    {
        _currentHotelContext = currentHotelContext;
        _currentUserService = currentUserService;
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

    public override int SaveChanges(bool acceptAllChangesOnSuccess)
    {
        AddTransactionalEvidence();
        return base.SaveChanges(acceptAllChangesOnSuccess);
    }

    public override Task<int> SaveChangesAsync(
        bool acceptAllChangesOnSuccess,
        CancellationToken cancellationToken = default)
    {
        AddTransactionalEvidence();
        return base.SaveChangesAsync(acceptAllChangesOnSuccess, cancellationToken);
    }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.ApplyConfigurationsFromAssembly(typeof(HotelMarketplaceDbContext).Assembly);
        ApplyHotelQueryFilters(modelBuilder);
    }

    private void AddTransactionalEvidence()
    {
        ChangeTracker.DetectChanges();

        List<Microsoft.EntityFrameworkCore.ChangeTracking.EntityEntry> protectedChanges = ChangeTracker
            .Entries()
            .Where(entry => AuditedEntityTypes.Contains(entry.Metadata.ClrType) &&
                entry.State is EntityState.Added or EntityState.Modified or EntityState.Deleted)
            .ToList();

        if (protectedChanges.Count == 0)
        {
            return;
        }

        HashSet<Guid> explicitlyAuditedTargets = ChangeTracker.Entries<AuditRecord>()
            .Where(entry => entry.State == EntityState.Added)
            .Select(entry => entry.Entity.TargetEntityId)
            .ToHashSet();
        HashSet<Guid> explicitlyNotifiedTargets = ChangeTracker.Entries<NotificationRecord>()
            .Where(entry => entry.State == EntityState.Added)
            .Select(entry => entry.Entity.RelatedEntityId)
            .ToHashSet();

        foreach (Microsoft.EntityFrameworkCore.ChangeTracking.EntityEntry entry in protectedChanges)
        {
            Entity entity = (Entity)entry.Entity;
            Guid? hotelId = ResolveHotelId(entry.Entity);

            if (!explicitlyAuditedTargets.Contains(entity.Id))
            {
                string operation = entry.State.ToString();
                AuditRecords.Add(new AuditRecord(
                    Guid.NewGuid(),
                    _currentUserService.UserId,
                    $"{entry.Metadata.ClrType.Name}.{operation}",
                    entry.Metadata.ClrType.Name,
                    entity.Id,
                    $"{entry.Metadata.ClrType.Name} was {operation.ToLowerInvariant()}.",
                    hotelId));
            }

            if (!explicitlyNotifiedTargets.Contains(entity.Id))
            {
                NotificationRecord? notification = CreateNotification(entry, hotelId);
                if (notification is not null)
                {
                    NotificationRecords.Add(notification);
                }
            }
        }
    }

    private static Guid? ResolveHotelId(object entity)
    {
        return entity switch
        {
            HotelProperty hotel => hotel.Id,
            IHotelScopedEntity hotelScoped => hotelScoped.HotelId,
            AuditRecord audit => audit.HotelId,
            NotificationRecord notification => notification.HotelId,
            _ => null
        };
    }

    private static NotificationRecord? CreateNotification(
        Microsoft.EntityFrameworkCore.ChangeTracking.EntityEntry entry,
        Guid? hotelId)
    {
        return entry.Entity switch
        {
            UserAccount user when entry.State == EntityState.Added => CreateNotification(
                user.Id, user.Id, "AccountRegistered", nameof(UserAccount),
                "Your account was registered successfully.", null),
            HotelProperty hotel when entry.State == EntityState.Added => CreateNotification(
                null, hotel.Id, "HotelSubmitted", nameof(HotelProperty),
                $"Hotel {hotel.Name} was submitted for platform review.", hotel.Id),
            HotelProperty hotel when PropertyChanged(entry, nameof(HotelProperty.ApprovalStatus)) => CreateNotification(
                hotel.OwnerUserAccountId, hotel.Id, $"Hotel{hotel.ApprovalStatus}", nameof(HotelProperty),
                $"Hotel {hotel.Name} is now {hotel.ApprovalStatus}.", hotel.Id),
            Booking booking when entry.State == EntityState.Added => CreateNotification(
                booking.CustomerUserAccountId, booking.Id, "BookingCreated", nameof(Booking),
                $"Booking {booking.BookingCode} was created.", booking.HotelId),
            Booking booking when PropertyChanged(entry, nameof(Booking.Status)) => CreateNotification(
                booking.CustomerUserAccountId, booking.Id, $"Booking{booking.Status}", nameof(Booking),
                $"Booking {booking.BookingCode} is now {booking.Status}.", booking.HotelId),
            HousekeepingTask task when entry.State == EntityState.Added => CreateNotification(
                task.AssignedToUserAccountId, task.Id, "HousekeepingTaskCreated", nameof(HousekeepingTask),
                "A housekeeping task was created.", task.HotelId),
            HousekeepingTask task when PropertyChanged(entry, nameof(HousekeepingTask.Status)) ||
                PropertyChanged(entry, nameof(HousekeepingTask.AssignedToUserAccountId)) => CreateNotification(
                task.AssignedToUserAccountId, task.Id, $"HousekeepingTask{task.Status}", nameof(HousekeepingTask),
                $"Housekeeping task is now {task.Status}.", task.HotelId),
            MaintenanceRequest request when entry.State == EntityState.Added => CreateNotification(
                request.AssignedToUserAccountId, request.Id, "MaintenanceRequestCreated", nameof(MaintenanceRequest),
                "A maintenance request was created.", request.HotelId),
            MaintenanceRequest request when PropertyChanged(entry, nameof(MaintenanceRequest.Status)) ||
                PropertyChanged(entry, nameof(MaintenanceRequest.AssignedToUserAccountId)) => CreateNotification(
                request.AssignedToUserAccountId, request.Id, $"MaintenanceRequest{request.Status}", nameof(MaintenanceRequest),
                $"Maintenance request is now {request.Status}.", request.HotelId),
            RefundRecord refund when entry.State == EntityState.Added || PropertyChanged(entry, nameof(RefundRecord.Status)) =>
                CreateNotification(null, refund.Id, $"Refund{refund.Status}", nameof(RefundRecord),
                    $"Refund request is now {refund.Status}.", hotelId),
            SettlementRecord settlement when entry.State == EntityState.Added || PropertyChanged(entry, nameof(SettlementRecord.Status)) =>
                CreateNotification(null, settlement.Id, $"Settlement{settlement.Status}", nameof(SettlementRecord),
                    $"Settlement is now {settlement.Status}.", settlement.HotelId),
            _ => null
        };
    }

    private static bool PropertyChanged(
        Microsoft.EntityFrameworkCore.ChangeTracking.EntityEntry entry,
        string propertyName)
    {
        return entry.State == EntityState.Modified && entry.Property(propertyName).IsModified;
    }

    private static NotificationRecord CreateNotification(
        Guid? recipientUserAccountId,
        Guid relatedEntityId,
        string eventType,
        string relatedEntityType,
        string message,
        Guid? hotelId)
    {
        return new NotificationRecord(
            Guid.NewGuid(),
            recipientUserAccountId,
            eventType,
            relatedEntityType,
            relatedEntityId,
            message,
            hotelId);
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
