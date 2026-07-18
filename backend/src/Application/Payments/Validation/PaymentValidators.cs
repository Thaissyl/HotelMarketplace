using FluentValidation;
using HotelMarketplace.Application.Common.Validation;
using HotelMarketplace.Application.Payments.Models;

namespace HotelMarketplace.Application.Payments.Validation;

internal sealed class PaymentWebhookRequestValidator : AbstractValidator<PaymentWebhookRequest>
{
    public PaymentWebhookRequestValidator()
    {
        RuleFor(request => request.Code).SafeRequiredText(32, "Webhook code");
        RuleFor(request => request.Desc).SafeRequiredText(256, "Webhook description");
        RuleFor(request => request.Signature).NotEmpty().MaximumLength(512);
        RuleFor(request => request.Data).NotNull();

        When(request => request.Data is not null, () =>
        {
            RuleFor(request => request.Data.OrderCode).GreaterThan(0);
            RuleFor(request => request.Data.Amount).GreaterThanOrEqualTo(0);
            RuleFor(request => request.Data.Description).SafeRequiredText(256, "Payment description");
            RuleFor(request => request.Data.AccountNumber).SafeRequiredText(64, "Account number");
            RuleFor(request => request.Data.Reference).SafeRequiredText(128, "Payment reference");
            RuleFor(request => request.Data.TransactionDateTime).SafeRequiredText(64, "Transaction date time");
            RuleFor(request => request.Data.Currency).SafeRequiredText(16, "Currency");
            RuleFor(request => request.Data.PaymentLinkId).SafeRequiredText(128, "Payment link id");
            RuleFor(request => request.Data.Code).SafeRequiredText(32, "Payment data code");
            RuleFor(request => request.Data.Desc).SafeRequiredText(256, "Payment data description");
            RuleFor(request => request.Data.CounterAccountBankId).SafeOptionalText(64, "Counter account bank id");
            RuleFor(request => request.Data.CounterAccountBankName).SafeOptionalText(256, "Counter account bank name");
            RuleFor(request => request.Data.CounterAccountName).SafeOptionalText(256, "Counter account name");
            RuleFor(request => request.Data.CounterAccountNumber).SafeOptionalText(64, "Counter account number");
            RuleFor(request => request.Data.VirtualAccountName).SafeOptionalText(256, "Virtual account name");
            RuleFor(request => request.Data.VirtualAccountNumber).SafeOptionalText(64, "Virtual account number");
        });
    }
}
