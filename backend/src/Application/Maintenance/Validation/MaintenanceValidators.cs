using FluentValidation;
using HotelMarketplace.Application.Maintenance.Requests;
using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.Maintenance.Validation;

internal sealed class MaintenanceRequestQueryRequestValidator : AbstractValidator<MaintenanceRequestQueryRequest>
{
    public MaintenanceRequestQueryRequestValidator()
    {
        RuleFor(request => request.AssignedToUserAccountId)
            .Must(userId => userId is null || userId.Value != Guid.Empty)
            .WithMessage("Assigned user id must be a valid identifier.");
    }
}

internal sealed class ReportRoomIssueRequestValidator : AbstractValidator<ReportRoomIssueRequest>
{
    public ReportRoomIssueRequestValidator()
    {
        RuleFor(request => request.PhysicalRoomId).NotEmpty();
        RuleFor(request => request.Description).NotEmpty().MaximumLength(1000);
        RuleFor(request => request.Severity).IsInEnum();
        RuleFor(request => request.TargetRoomStatus)
            .Must(status => status is RoomOperationalStatus.Maintenance or RoomOperationalStatus.OutOfService)
            .WithMessage("Target room status must be Maintenance or OutOfService.");
    }
}

internal sealed class UpdateMaintenanceRequestStatusRequestValidator : AbstractValidator<UpdateMaintenanceRequestStatusRequest>
{
    public UpdateMaintenanceRequestStatusRequestValidator()
    {
        RuleFor(request => request.Status)
            .Must(status => status is MaintenanceStatus.InProgress or MaintenanceStatus.Resolved)
            .WithMessage("Maintenance requests can only be moved to InProgress or Resolved through this workflow.");
    }
}
