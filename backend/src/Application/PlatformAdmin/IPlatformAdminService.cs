using HotelMarketplace.Application.PlatformAdmin.Dtos;
using HotelMarketplace.Application.PlatformAdmin.Requests;
using HotelMarketplace.Domain.Enums;
using HotelMarketplace.SharedKernel.Results;

namespace HotelMarketplace.Application.PlatformAdmin;

public interface IPlatformAdminService
{
    Task<Result<IReadOnlyCollection<AdminHotelDto>>> GetPendingHotelsAsync(CancellationToken cancellationToken);
    Task<Result<AdminHotelDto>> ApproveHotelAsync(Guid hotelId, CancellationToken cancellationToken);
    Task<Result<AdminHotelDto>> RejectHotelAsync(Guid hotelId, RejectHotelRequest request, CancellationToken cancellationToken);
    Task<Result<AdminHotelDto>> UpdateCommissionRateAsync(Guid hotelId, UpdateCommissionRateRequest request, CancellationToken cancellationToken);
    Task<Result<IReadOnlyCollection<AdminFinanceSummaryDto>>> GetFinanceSummaryAsync(Guid? hotelId, DateOnly? fromDate, DateOnly? toDate, CancellationToken cancellationToken);
    Task<Result<IReadOnlyCollection<AdminPaymentTransactionDto>>> GetPaymentTransactionsAsync(ReconciliationStatus? reconciliationStatus, CancellationToken cancellationToken);
    Task<Result<AdminPaymentTransactionDto>> UpdatePaymentReconciliationAsync(Guid paymentTransactionId, UpdatePaymentReconciliationRequest request, CancellationToken cancellationToken);
    Task<Result<IReadOnlyCollection<AdminSettlementDto>>> GetSettlementsAsync(Guid? hotelId, SettlementStatus? status, CancellationToken cancellationToken);
    Task<Result<AdminSettlementDto>> CreateSettlementAsync(CreateSettlementRequest request, CancellationToken cancellationToken);
    Task<Result<AdminSettlementDto>> UpdateSettlementStatusAsync(Guid settlementId, UpdateSettlementStatusRequest request, CancellationToken cancellationToken);
    Task<Result<IReadOnlyCollection<AdminRefundDto>>> GetRefundsAsync(RefundStatus? status, CancellationToken cancellationToken);
    Task<Result<AdminRefundDto>> UpdateRefundStatusAsync(Guid refundId, UpdateRefundStatusRequest request, CancellationToken cancellationToken);
}
