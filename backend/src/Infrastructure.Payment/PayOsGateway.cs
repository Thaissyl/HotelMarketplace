using System.Globalization;
using System.Net.Http.Json;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using HotelMarketplace.Application.Payments;
using HotelMarketplace.Application.Payments.Models;

namespace HotelMarketplace.Infrastructure.Payment;

internal sealed class PayOsGateway : IPayOsGateway, IDisposable
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web)
    {
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
    };

    private readonly PayOsOptions _options;
    private readonly HttpClient _httpClient;

    public PayOsGateway(PayOsOptions options)
    {
        _options = options;
        _httpClient = new HttpClient
        {
            BaseAddress = new Uri(string.IsNullOrWhiteSpace(options.BaseUrl)
                ? "https://api-merchant.payos.vn"
                : options.BaseUrl.TrimEnd('/'))
        };
    }

    public async Task<CreatePaymentLinkGatewayResult> CreatePaymentLinkAsync(
        CreatePaymentLinkGatewayRequest request,
        CancellationToken cancellationToken)
    {
        EnsureConfigured();

        PayOsCreatePaymentLinkRequest payOsRequest = new(
            request.OrderCode,
            request.Amount,
            TrimDescription(request.Description),
            request.BuyerName,
            request.BuyerEmail,
            request.BuyerPhone,
            _options.CancelUrl,
            _options.ReturnUrl,
            new DateTimeOffset(request.ExpiresAtUtc).ToUnixTimeSeconds(),
            CreatePaymentLinkSignature(request.OrderCode, request.Amount, TrimDescription(request.Description)));

        using HttpRequestMessage httpRequest = new(HttpMethod.Post, "/v2/payment-requests")
        {
            Content = JsonContent.Create(payOsRequest, options: JsonOptions)
        };

        httpRequest.Headers.TryAddWithoutValidation("x-client-id", _options.ClientId);
        httpRequest.Headers.TryAddWithoutValidation("x-api-key", _options.ApiKey);

        using HttpResponseMessage response = await _httpClient.SendAsync(httpRequest, cancellationToken);
        PayOsEnvelope<PayOsCreatePaymentLinkData>? envelope = await response.Content
            .ReadFromJsonAsync<PayOsEnvelope<PayOsCreatePaymentLinkData>>(JsonOptions, cancellationToken);

        if (!response.IsSuccessStatusCode || envelope is null || envelope.Code != "00" || envelope.Data is null)
        {
            string gatewayMessage = envelope?.Desc ?? response.ReasonPhrase ?? "payOS payment link request failed.";
            throw new InvalidOperationException(gatewayMessage);
        }

        return new CreatePaymentLinkGatewayResult(
            envelope.Data.OrderCode,
            envelope.Data.Amount,
            envelope.Data.CheckoutUrl,
            envelope.Data.PaymentLinkId,
            envelope.Data.QrCode,
            envelope.Data.Status);
    }

    public bool VerifyWebhook(PaymentWebhookRequest request)
    {
        if (string.IsNullOrWhiteSpace(_options.ChecksumKey) || string.IsNullOrWhiteSpace(request.Signature))
        {
            return false;
        }

        Dictionary<string, string> values = new(StringComparer.Ordinal)
        {
            ["accountNumber"] = request.Data.AccountNumber,
            ["amount"] = request.Data.Amount.ToString(CultureInfo.InvariantCulture),
            ["code"] = request.Data.Code,
            ["currency"] = request.Data.Currency,
            ["description"] = request.Data.Description,
            ["orderCode"] = request.Data.OrderCode.ToString(CultureInfo.InvariantCulture),
            ["paymentLinkId"] = request.Data.PaymentLinkId,
            ["reference"] = request.Data.Reference,
            ["transactionDateTime"] = request.Data.TransactionDateTime
        };

        AddIfNotNull(values, "counterAccountBankId", request.Data.CounterAccountBankId);
        AddIfNotNull(values, "counterAccountBankName", request.Data.CounterAccountBankName);
        AddIfNotNull(values, "counterAccountName", request.Data.CounterAccountName);
        AddIfNotNull(values, "counterAccountNumber", request.Data.CounterAccountNumber);
        AddIfNotNull(values, "desc", request.Data.Desc);
        AddIfNotNull(values, "virtualAccountName", request.Data.VirtualAccountName);
        AddIfNotNull(values, "virtualAccountNumber", request.Data.VirtualAccountNumber);

        string data = string.Join("&", values.OrderBy(pair => pair.Key, StringComparer.Ordinal).Select(pair => $"{pair.Key}={pair.Value}"));
        string expectedSignature = HmacSha256(data, _options.ChecksumKey);

        return CryptographicOperations.FixedTimeEquals(
            Encoding.UTF8.GetBytes(expectedSignature),
            Encoding.UTF8.GetBytes(request.Signature.ToLowerInvariant()));
    }

    private string CreatePaymentLinkSignature(long orderCode, int amount, string description)
    {
        string data = string.Format(
            CultureInfo.InvariantCulture,
            "amount={0}&cancelUrl={1}&description={2}&orderCode={3}&returnUrl={4}",
            amount,
            _options.CancelUrl,
            description,
            orderCode,
            _options.ReturnUrl);

        return HmacSha256(data, _options.ChecksumKey);
    }

    private void EnsureConfigured()
    {
        if (string.IsNullOrWhiteSpace(_options.ClientId) ||
            string.IsNullOrWhiteSpace(_options.ApiKey) ||
            string.IsNullOrWhiteSpace(_options.ChecksumKey) ||
            string.IsNullOrWhiteSpace(_options.ReturnUrl) ||
            string.IsNullOrWhiteSpace(_options.CancelUrl))
        {
            throw new InvalidOperationException("payOS configuration is incomplete.");
        }
    }

    private static string HmacSha256(string data, string key)
    {
        using HMACSHA256 hmac = new(Encoding.UTF8.GetBytes(key));
        byte[] hash = hmac.ComputeHash(Encoding.UTF8.GetBytes(data));
        return Convert.ToHexString(hash).ToLowerInvariant();
    }

    private static string TrimDescription(string description)
    {
        string trimmed = description.Trim();
        return trimmed.Length <= 25 ? trimmed : trimmed[..25];
    }

    private static void AddIfNotNull(Dictionary<string, string> values, string key, string? value)
    {
        if (value is not null)
        {
            values[key] = value;
        }
    }

    public void Dispose()
    {
        _httpClient.Dispose();
    }

    private sealed record PayOsCreatePaymentLinkRequest(
        long OrderCode,
        int Amount,
        string Description,
        string BuyerName,
        string? BuyerEmail,
        string BuyerPhone,
        string CancelUrl,
        string ReturnUrl,
        long ExpiredAt,
        string Signature);

    private sealed record PayOsEnvelope<TData>(
        string Code,
        string Desc,
        TData? Data,
        string? Signature);

    private sealed record PayOsCreatePaymentLinkData(
        int Amount,
        string Description,
        long OrderCode,
        string Currency,
        string PaymentLinkId,
        string Status,
        string CheckoutUrl,
        string QrCode);
}
