using FluentValidation;
using FluentValidation.Results;
using HotelMarketplace.Application.Common.Validation;
using HotelMarketplace.Application.PlatformAdmin.Dtos;
using HotelMarketplace.Application.PlatformAdmin.Requests;
using HotelMarketplace.Application.Security;
using HotelMarketplace.Domain.Enums;
using HotelMarketplace.SharedKernel.Results;

namespace HotelMarketplace.Application.PlatformAdmin;

internal sealed class PlatformAdminService : IPlatformAdminService
{
    private readonly ICurrentUserService _currentUserService;
    private readonly IPlatformAdminRepository _platformAdminRepository;
    private readonly IValidator<RejectHotelRequest> _rejectHotelValidator;
    private readonly IValidator<UpdateCommissionRateRequest> _commissionRateValidator;
    private readonly IValidator<CreateSettlementRequest> _createSettlementValidator;
    private readonly IValidator<UpdateSettlementStatusRequest> _settlementStatusValidator;
    private readonly IValidator<UpdateRefundStatusRequest> _refundStatusValidator;
    private readonly IValidator<UpdatePaymentReconciliationRequest> _reconciliationValidator;

    public PlatformAdminService(
        ICurrentUserService currentUserService,
        IPlatformAdminRepository platformAdminRepository,
        IValidator<RejectHotelRequest> rejectHotelValidator,
        IValidator<UpdateCommissionRateRequest> commissionRateValidator,
        IValidator<CreateSettlementRequest> createSettlementValidator,
        IValidator<UpdateSettlementStatusRequest> settlementStatusValidator,
        IValidator<UpdateRefundStatusRequest> refundStatusValidator,
        IValidator<UpdatePaymentReconciliationRequest> reconciliationValidator)
    {
        _currentUserService = currentUserService;
        _platformAdminRepository = platformAdminRepository;
        _rejectHotelValidator = rejectHotelValidator;
        _commissionRateValidator = commissionRateValidator;
        _createSettlementValidator = createSettlementValidator;
        _settlementStatusValidator = settlementStatusValidator;
        _refundStatusValidator = refundStatusValidator;
        _reconciliationValidator = reconciliationValidator;
    }

    public async Task<Result<IReadOnlyCollection<AdminUserDto>>> GetUsersAsync(
        UserRoleCode? role,
        string? searchTerm,
        CancellationToken cancellationToken)
    {
        Result? authorizationFailure = ValidatePlatformAdministrator();
        if (authorizationFailure is not null)
        {
            return Result.Failure<IReadOnlyCollection<AdminUserDto>>(authorizationFailure.Error);
        }

        string? normalizedSearchTerm = string.IsNullOrWhiteSpace(searchTerm)
            ? null
            : searchTerm.Trim();

        return Result.Success(await _platformAdminRepository.GetUsersAsync(role, normalizedSearchTerm, cancellationToken));
    }

    public async Task<Result<AdminUserDto>> SuspendUserAsync(Guid userId, CancellationToken cancellationToken)
    {
        Result? authorizationFailure = ValidatePlatformAdministrator();
        if (authorizationFailure is not null)
        {
            return Result.Failure<AdminUserDto>(authorizationFailure.Error);
        }

        if (userId == _currentUserService.UserId)
        {
            return Result.Failure<AdminUserDto>(PlatformAdminErrors.InvalidUserStatus);
        }

        return ToUserResult(await _platformAdminRepository.SuspendUserAsync(
            userId,
            _currentUserService.UserId!.Value,
            cancellationToken));
    }

    public async Task<Result<AdminUserDto>> ReactivateUserAsync(Guid userId, CancellationToken cancellationToken)
    {
        Result? authorizationFailure = ValidatePlatformAdministrator();
        if (authorizationFailure is not null)
        {
            return Result.Failure<AdminUserDto>(authorizationFailure.Error);
        }

        return ToUserResult(await _platformAdminRepository.ReactivateUserAsync(
            userId,
            _currentUserService.UserId!.Value,
            cancellationToken));
    }

    public async Task<Result<IReadOnlyCollection<AdminUserActivityDto>>> GetUserActivityAsync(
        Guid userId,
        CancellationToken cancellationToken)
    {
        Result? authorizationFailure = ValidatePlatformAdministrator();
        if (authorizationFailure is not null)
        {
            return Result.Failure<IReadOnlyCollection<AdminUserActivityDto>>(authorizationFailure.Error);
        }

        return Result.Success(await _platformAdminRepository.GetUserActivityAsync(userId, cancellationToken));
    }

    public async Task<Result<IReadOnlyCollection<AdminHotelDto>>> GetPendingHotelsAsync(CancellationToken cancellationToken)
    {
        Result? authorizationFailure = ValidatePlatformAdministrator();
        if (authorizationFailure is not null)
        {
            return Result.Failure<IReadOnlyCollection<AdminHotelDto>>(authorizationFailure.Error);
        }

        return Result.Success(await _platformAdminRepository.GetPendingHotelsAsync(cancellationToken));
    }

    public async Task<Result<AdminHotelDto>> ApproveHotelAsync(Guid hotelId, CancellationToken cancellationToken)
    {
        Result? authorizationFailure = ValidatePlatformAdministrator();
        if (authorizationFailure is not null)
        {
            return Result.Failure<AdminHotelDto>(authorizationFailure.Error);
        }

        return ToHotelResult(await _platformAdminRepository.ApproveHotelAsync(hotelId, _currentUserService.UserId!.Value, cancellationToken));
    }

    public async Task<Result<AdminHotelDto>> RejectHotelAsync(Guid hotelId, RejectHotelRequest request, CancellationToken cancellationToken)
    {
        Result? authorizationFailure = ValidatePlatformAdministrator();
        if (authorizationFailure is not null)
        {
            return Result.Failure<AdminHotelDto>(authorizationFailure.Error);
        }

        ValidationResult validationResult = await _rejectHotelValidator.ValidateAsync(request, cancellationToken);
        if (!validationResult.IsValid)
        {
            return Result.Failure<AdminHotelDto>(
                ValidationErrorFormatter.ToResultError("PlatformAdmin.InvalidHotelRejectionRequest", validationResult));
        }

        return ToHotelResult(await _platformAdminRepository.RejectHotelAsync(hotelId, _currentUserService.UserId!.Value, request, cancellationToken));
    }

    public async Task<Result<AdminHotelDto>> UpdateCommissionRateAsync(Guid hotelId, UpdateCommissionRateRequest request, CancellationToken cancellationToken)
    {
        Result? authorizationFailure = ValidatePlatformAdministrator();
        if (authorizationFailure is not null)
        {
            return Result.Failure<AdminHotelDto>(authorizationFailure.Error);
        }

        ValidationResult validationResult = await _commissionRateValidator.ValidateAsync(request, cancellationToken);
        if (!validationResult.IsValid)
        {
            return Result.Failure<AdminHotelDto>(
                ValidationErrorFormatter.ToResultError("PlatformAdmin.InvalidCommissionRateRequest", validationResult));
        }

        return ToHotelResult(await _platformAdminRepository.UpdateCommissionRateAsync(hotelId, _currentUserService.UserId!.Value, request, cancellationToken));
    }

    public async Task<Result<IReadOnlyCollection<AdminFinanceSummaryDto>>> GetFinanceSummaryAsync(
        Guid? hotelId,
        DateOnly? fromDate,
        DateOnly? toDate,
        CancellationToken cancellationToken)
    {
        Result? authorizationFailure = ValidatePlatformAdministrator();
        if (authorizationFailure is not null)
        {
            return Result.Failure<IReadOnlyCollection<AdminFinanceSummaryDto>>(authorizationFailure.Error);
        }

        if (fromDate.HasValue && toDate.HasValue && toDate.Value < fromDate.Value)
        {
            return Result.Failure<IReadOnlyCollection<AdminFinanceSummaryDto>>(
                new ResultError("PlatformAdmin.InvalidDateRange", "To date must be greater than or equal to from date."));
        }

        return Result.Success(await _platformAdminRepository.GetFinanceSummaryAsync(hotelId, fromDate, toDate, cancellationToken));
    }

    public async Task<Result<IReadOnlyCollection<AdminPaymentTransactionDto>>> GetPaymentTransactionsAsync(
        ReconciliationStatus? reconciliationStatus,
        CancellationToken cancellationToken)
    {
        Result? authorizationFailure = ValidatePlatformAdministrator();
        if (authorizationFailure is not null)
        {
            return Result.Failure<IReadOnlyCollection<AdminPaymentTransactionDto>>(authorizationFailure.Error);
        }

        return Result.Success(await _platformAdminRepository.GetPaymentTransactionsAsync(reconciliationStatus, cancellationToken));
    }

    public async Task<Result<AdminPaymentTransactionDto>> UpdatePaymentReconciliationAsync(
        Guid paymentTransactionId,
        UpdatePaymentReconciliationRequest request,
        CancellationToken cancellationToken)
    {
        Result? authorizationFailure = ValidatePlatformAdministrator();
        if (authorizationFailure is not null)
        {
            return Result.Failure<AdminPaymentTransactionDto>(authorizationFailure.Error);
        }

        ValidationResult validationResult = await _reconciliationValidator.ValidateAsync(request, cancellationToken);
        if (!validationResult.IsValid)
        {
            return Result.Failure<AdminPaymentTransactionDto>(
                ValidationErrorFormatter.ToResultError("PlatformAdmin.InvalidReconciliationRequest", validationResult));
        }

        return ToPaymentResult(await _platformAdminRepository.UpdatePaymentReconciliationAsync(
            paymentTransactionId,
            _currentUserService.UserId!.Value,
            request,
            cancellationToken));
    }

    public async Task<Result<IReadOnlyCollection<AdminSettlementDto>>> GetSettlementsAsync(
        Guid? hotelId,
        SettlementStatus? status,
        CancellationToken cancellationToken)
    {
        Result? authorizationFailure = ValidatePlatformAdministrator();
        if (authorizationFailure is not null)
        {
            return Result.Failure<IReadOnlyCollection<AdminSettlementDto>>(authorizationFailure.Error);
        }

        return Result.Success(await _platformAdminRepository.GetSettlementsAsync(hotelId, status, cancellationToken));
    }

    public async Task<Result<AdminSettlementDto>> CreateSettlementAsync(
        CreateSettlementRequest request,
        CancellationToken cancellationToken)
    {
        Result? authorizationFailure = ValidatePlatformAdministrator();
        if (authorizationFailure is not null)
        {
            return Result.Failure<AdminSettlementDto>(authorizationFailure.Error);
        }

        ValidationResult validationResult = await _createSettlementValidator.ValidateAsync(request, cancellationToken);
        if (!validationResult.IsValid)
        {
            return Result.Failure<AdminSettlementDto>(
                ValidationErrorFormatter.ToResultError("PlatformAdmin.InvalidSettlementRequest", validationResult));
        }

        return ToSettlementResult(await _platformAdminRepository.CreateSettlementAsync(
            _currentUserService.UserId!.Value,
            request,
            cancellationToken));
    }

    public async Task<Result<AdminSettlementDto>> UpdateSettlementStatusAsync(
        Guid settlementId,
        UpdateSettlementStatusRequest request,
        CancellationToken cancellationToken)
    {
        Result? authorizationFailure = ValidatePlatformAdministrator();
        if (authorizationFailure is not null)
        {
            return Result.Failure<AdminSettlementDto>(authorizationFailure.Error);
        }

        ValidationResult validationResult = await _settlementStatusValidator.ValidateAsync(request, cancellationToken);
        if (!validationResult.IsValid)
        {
            return Result.Failure<AdminSettlementDto>(
                ValidationErrorFormatter.ToResultError("PlatformAdmin.InvalidSettlementStatusRequest", validationResult));
        }

        return ToSettlementResult(await _platformAdminRepository.UpdateSettlementStatusAsync(
            settlementId,
            _currentUserService.UserId!.Value,
            request,
            cancellationToken));
    }

    public async Task<Result<IReadOnlyCollection<AdminRefundDto>>> GetRefundsAsync(
        RefundStatus? status,
        CancellationToken cancellationToken)
    {
        Result? authorizationFailure = ValidatePlatformAdministrator();
        if (authorizationFailure is not null)
        {
            return Result.Failure<IReadOnlyCollection<AdminRefundDto>>(authorizationFailure.Error);
        }

        return Result.Success(await _platformAdminRepository.GetRefundsAsync(status, cancellationToken));
    }

    public async Task<Result<AdminRefundDto>> UpdateRefundStatusAsync(
        Guid refundId,
        UpdateRefundStatusRequest request,
        CancellationToken cancellationToken)
    {
        Result? authorizationFailure = ValidatePlatformAdministrator();
        if (authorizationFailure is not null)
        {
            return Result.Failure<AdminRefundDto>(authorizationFailure.Error);
        }

        ValidationResult validationResult = await _refundStatusValidator.ValidateAsync(request, cancellationToken);
        if (!validationResult.IsValid)
        {
            return Result.Failure<AdminRefundDto>(
                ValidationErrorFormatter.ToResultError("PlatformAdmin.InvalidRefundStatusRequest", validationResult));
        }

        return ToRefundResult(await _platformAdminRepository.UpdateRefundStatusAsync(
            refundId,
            _currentUserService.UserId!.Value,
            request,
            cancellationToken));
    }

    private Result? ValidatePlatformAdministrator()
    {
        return _currentUserService.UserId is not null &&
            _currentUserService.Roles.Contains(UserRoleCode.PlatformAdministrator)
            ? null
            : Result.Failure(PlatformAdminErrors.Forbidden);
    }

    private static Result<AdminHotelDto> ToHotelResult(PlatformAdminHotelResult result)
    {
        return result.Status switch
        {
            PlatformAdminPersistenceStatus.Success => Result.Success(result.Hotel!),
            PlatformAdminPersistenceStatus.HotelNotFound => Result.Failure<AdminHotelDto>(PlatformAdminErrors.HotelNotFound),
            PlatformAdminPersistenceStatus.InvalidHotelReviewState => Result.Failure<AdminHotelDto>(PlatformAdminErrors.InvalidHotelReviewState),
            PlatformAdminPersistenceStatus.LockUnavailable => Result.Failure<AdminHotelDto>(PlatformAdminErrors.LockUnavailable),
            _ => Result.Failure<AdminHotelDto>(PlatformAdminErrors.HotelNotFound)
        };
    }

    private static Result<AdminUserDto> ToUserResult(PlatformAdminUserResult result)
    {
        return result.Status switch
        {
            PlatformAdminPersistenceStatus.Success => Result.Success(result.User!),
            PlatformAdminPersistenceStatus.UserNotFound => Result.Failure<AdminUserDto>(PlatformAdminErrors.UserNotFound),
            PlatformAdminPersistenceStatus.InvalidUserStatus => Result.Failure<AdminUserDto>(PlatformAdminErrors.InvalidUserStatus),
            PlatformAdminPersistenceStatus.LockUnavailable => Result.Failure<AdminUserDto>(PlatformAdminErrors.LockUnavailable),
            _ => Result.Failure<AdminUserDto>(PlatformAdminErrors.UserNotFound)
        };
    }

    private static Result<AdminSettlementDto> ToSettlementResult(PlatformAdminSettlementResult result)
    {
        return result.Status switch
        {
            PlatformAdminPersistenceStatus.Success => Result.Success(result.Settlement!),
            PlatformAdminPersistenceStatus.SettlementNotFound => Result.Failure<AdminSettlementDto>(PlatformAdminErrors.SettlementNotFound),
            PlatformAdminPersistenceStatus.SettlementNotEligible => Result.Failure<AdminSettlementDto>(PlatformAdminErrors.SettlementNotEligible),
            PlatformAdminPersistenceStatus.InvalidSettlementStatus => Result.Failure<AdminSettlementDto>(PlatformAdminErrors.InvalidSettlementStatus),
            PlatformAdminPersistenceStatus.LockUnavailable => Result.Failure<AdminSettlementDto>(PlatformAdminErrors.LockUnavailable),
            _ => Result.Failure<AdminSettlementDto>(PlatformAdminErrors.InvalidSettlementStatus)
        };
    }

    private static Result<AdminRefundDto> ToRefundResult(PlatformAdminRefundResult result)
    {
        return result.Status switch
        {
            PlatformAdminPersistenceStatus.Success => Result.Success(result.Refund!),
            PlatformAdminPersistenceStatus.RefundNotFound => Result.Failure<AdminRefundDto>(PlatformAdminErrors.RefundNotFound),
            PlatformAdminPersistenceStatus.InvalidRefundStatus => Result.Failure<AdminRefundDto>(PlatformAdminErrors.InvalidRefundStatus),
            PlatformAdminPersistenceStatus.LockUnavailable => Result.Failure<AdminRefundDto>(PlatformAdminErrors.LockUnavailable),
            _ => Result.Failure<AdminRefundDto>(PlatformAdminErrors.InvalidRefundStatus)
        };
    }

    private static Result<AdminPaymentTransactionDto> ToPaymentResult(PlatformAdminPaymentResult result)
    {
        return result.Status switch
        {
            PlatformAdminPersistenceStatus.Success => Result.Success(result.PaymentTransaction!),
            PlatformAdminPersistenceStatus.PaymentTransactionNotFound => Result.Failure<AdminPaymentTransactionDto>(PlatformAdminErrors.PaymentTransactionNotFound),
            PlatformAdminPersistenceStatus.InvalidReconciliationStatus => Result.Failure<AdminPaymentTransactionDto>(PlatformAdminErrors.InvalidReconciliationStatus),
            PlatformAdminPersistenceStatus.LockUnavailable => Result.Failure<AdminPaymentTransactionDto>(PlatformAdminErrors.LockUnavailable),
            _ => Result.Failure<AdminPaymentTransactionDto>(PlatformAdminErrors.InvalidReconciliationStatus)
        };
    }
}
