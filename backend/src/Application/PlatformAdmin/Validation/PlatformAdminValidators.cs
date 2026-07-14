using FluentValidation;
using HotelMarketplace.Application.PlatformAdmin.Requests;
using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.PlatformAdmin.Validation;

internal sealed class RejectHotelRequestValidator : AbstractValidator<RejectHotelRequest>
{
    public RejectHotelRequestValidator()
    {
        RuleFor(request => request.Reason).NotEmpty().MaximumLength(900);
    }
}

internal sealed class UpdateCommissionRateRequestValidator : AbstractValidator<UpdateCommissionRateRequest>
{
    public UpdateCommissionRateRequestValidator()
    {
        RuleFor(request => request.CommissionRate).InclusiveBetween(0m, 0.30m);
    }
}

internal sealed class CreateSettlementRequestValidator : AbstractValidator<CreateSettlementRequest>
{
    public CreateSettlementRequestValidator()
    {
        RuleFor(request => request.HotelId).NotEmpty();
        RuleFor(request => request.PaymentMode)
            .Must(mode => mode is PaymentMode.PlatformCollect or PaymentMode.PayAtProperty)
            .WithMessage("Settlement payment mode must be PlatformCollect or PayAtProperty.");
        RuleFor(request => request.ToDate)
            .GreaterThanOrEqualTo(request => request.FromDate)
            .WithMessage("To date must be greater than or equal to from date.");
        RuleFor(request => request.AdminNote).MaximumLength(1000);
    }
}

internal sealed class UpdateSettlementStatusRequestValidator : AbstractValidator<UpdateSettlementStatusRequest>
{
    public UpdateSettlementStatusRequestValidator()
    {
        RuleFor(request => request.Status)
            .Must(status => status is SettlementStatus.Settled or SettlementStatus.Exception)
            .WithMessage("Settlement can only be marked as Settled or Exception through this workflow.");
        RuleFor(request => request.AdminNote)
            .NotEmpty()
            .When(request => request.Status == SettlementStatus.Exception)
            .WithMessage("Admin note is required when marking settlement as exception.");
        RuleFor(request => request.AdminNote).MaximumLength(1000);
    }
}

internal sealed class UpdateRefundStatusRequestValidator : AbstractValidator<UpdateRefundStatusRequest>
{
    public UpdateRefundStatusRequestValidator()
    {
        RuleFor(request => request.Status)
            .Must(status => status is RefundStatus.Approved or RefundStatus.Rejected or RefundStatus.Processed or RefundStatus.Failed)
            .WithMessage("Refund can only be marked as Approved, Rejected, Processed, or Failed.");
        RuleFor(request => request.ApprovedAmount)
            .NotNull()
            .GreaterThanOrEqualTo(0m)
            .When(request => request.Status == RefundStatus.Approved)
            .WithMessage("Approved amount is required when approving a refund.");
    }
}

internal sealed class UpdatePaymentReconciliationRequestValidator : AbstractValidator<UpdatePaymentReconciliationRequest>
{
    public UpdatePaymentReconciliationRequestValidator()
    {
        RuleFor(request => request.Status)
            .Must(status => status is ReconciliationStatus.Reconciled or ReconciliationStatus.Exception)
            .WithMessage("Payment transaction can only be marked as Reconciled or Exception.");
    }
}
