using FluentValidation;
using HotelMarketplace.Application.Housekeeping.Requests;
using HotelMarketplace.Domain.Enums;

namespace HotelMarketplace.Application.Housekeeping.Validation;

internal sealed class HousekeepingTaskQueryRequestValidator : AbstractValidator<HousekeepingTaskQueryRequest>
{
    public HousekeepingTaskQueryRequestValidator()
    {
        RuleFor(request => request.AssignedToUserAccountId)
            .Must(userId => userId is null || userId.Value != Guid.Empty)
            .WithMessage("Assigned user id must be a valid identifier.");
    }
}

internal sealed class UpdateHousekeepingTaskStatusRequestValidator : AbstractValidator<UpdateHousekeepingTaskStatusRequest>
{
    public UpdateHousekeepingTaskStatusRequestValidator()
    {
        RuleFor(request => request.Status)
            .Must(status => status is HousekeepingTaskStatus.InProgress or HousekeepingTaskStatus.Completed)
            .WithMessage("Housekeeping tasks can only be moved to InProgress or Completed through this workflow.");
    }
}
