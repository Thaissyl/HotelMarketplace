using HotelMarketplace.Application.PlatformAdmin.Dtos;
using HotelMarketplace.Application.PlatformAdmin.Requests;
using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.PlatformAdmin;

public interface IPlatformAdminRepository
{
    Task<IReadOnlyCollection<AdminUserDto>> GetUsersAsync(UserRoleCode? role, string? searchTerm, CancellationToken cancellationToken);

    Task<PlatformAdminUserResult> SuspendUserAsync(Guid userId, Guid actorUserAccountId, CancellationToken cancellationToken);

    Task<PlatformAdminUserResult> ReactivateUserAsync(Guid userId, Guid actorUserAccountId, CancellationToken cancellationToken);

    Task<IReadOnlyCollection<AdminUserActivityDto>> GetUserActivityAsync(Guid userId, CancellationToken cancellationToken);

    Task<IReadOnlyCollection<AdminHotelDto>> GetPendingHotelsAsync(CancellationToken cancellationToken);

    Task<IReadOnlyCollection<AdminHotelDto>> GetHotelsAsync(CancellationToken cancellationToken);

    Task<PlatformAdminHotelResult> ApproveHotelAsync(Guid hotelId, Guid actorUserAccountId, CancellationToken cancellationToken);

    Task<PlatformAdminHotelResult> RejectHotelAsync(Guid hotelId, Guid actorUserAccountId, RejectHotelRequest request, CancellationToken cancellationToken);

    Task<PlatformAdminHotelResult> UpdateCommissionRateAsync(Guid hotelId, Guid actorUserAccountId, UpdateCommissionRateRequest request, CancellationToken cancellationToken);

    Task<IReadOnlyCollection<AdminFinanceSummaryDto>> GetFinanceSummaryAsync(Guid? hotelId, DateOnly? fromDate, DateOnly? toDate, CancellationToken cancellationToken);

    Task<IReadOnlyCollection<AdminPaymentTransactionDto>> GetPaymentTransactionsAsync(ReconciliationStatus? reconciliationStatus, CancellationToken cancellationToken);

    Task<PlatformAdminPaymentResult> UpdatePaymentReconciliationAsync(Guid paymentTransactionId, Guid actorUserAccountId, UpdatePaymentReconciliationRequest request, CancellationToken cancellationToken);

    Task<IReadOnlyCollection<AdminSettlementDto>> GetSettlementsAsync(Guid? hotelId, SettlementStatus? status, CancellationToken cancellationToken);

    Task<PlatformAdminSettlementResult> CreateSettlementAsync(Guid actorUserAccountId, CreateSettlementRequest request, CancellationToken cancellationToken);

    Task<PlatformAdminSettlementResult> UpdateSettlementStatusAsync(Guid settlementId, Guid actorUserAccountId, UpdateSettlementStatusRequest request, CancellationToken cancellationToken);

    Task<IReadOnlyCollection<AdminRefundDto>> GetRefundsAsync(RefundStatus? status, CancellationToken cancellationToken);

    Task<PlatformAdminRefundResult> UpdateRefundStatusAsync(Guid refundId, Guid actorUserAccountId, UpdateRefundStatusRequest request, CancellationToken cancellationToken);
}
