using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;
using FluentAssertions;
using HotelMarketplace.Application.Availability.Dtos;
using HotelMarketplace.Application.Bookings.Dtos;
using HotelMarketplace.Application.Bookings.Expiration;
using HotelMarketplace.Application.CustomerAccount.Dtos;
using HotelMarketplace.Application.FrontDesk.Dtos;
using HotelMarketplace.Application.HotelManagement.Dtos;
using HotelMarketplace.Application.Housekeeping.Dtos;
using HotelMarketplace.Application.Maintenance.Dtos;
using HotelMarketplace.Application.Marketplace.Dtos;
using HotelMarketplace.Application.Payments.Dtos;
using HotelMarketplace.Application.PlatformAdmin.Dtos;
using HotelMarketplace.Domain.Entities;
using HotelMarketplace.Domain.Enums;
using HotelMarketplace.Domain.Security;
using HotelMarketplace.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace HotelMarketplace.Api.IntegrationTests;

public sealed class ApiIntegrationTests : IClassFixture<HotelMarketplaceApiFactory>
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web)
    {
        Converters = { new JsonStringEnumConverter() }
    };

    private readonly HotelMarketplaceApiFactory _factory;

    public ApiIntegrationTests(HotelMarketplaceApiFactory factory)
    {
        _factory = factory;
    }

    [Fact]
    public async Task RegisterRejectsSwaggerPlaceholderAndInvalidPhoneNumber()
    {
        using HttpClient client = _factory.CreateClient();

        using HttpResponseMessage response = await client.PostAsJsonAsync(
            "/api/auth/register",
            new
            {
                email = "string",
                password = "string",
                fullName = "string",
                phoneNumber = "string",
                role = UserRoleCode.Customer
            },
            JsonOptions);

        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);

        string responseBody = await response.Content.ReadAsStringAsync();
        responseBody.Should().Contain("Phone number must contain exactly 10 digits.");
        responseBody.Should().Contain("Email must be a real email address.");
    }

    [Fact]
    public async Task RegisterLoginAndHotelScopedMiddlewareReturnsForbiddenForAnotherHotel()
    {
        using HttpClient client = _factory.CreateClient();
        string suffix = Guid.NewGuid().ToString("N");

        TestAuthResponse registeredOwner = await PostJsonAsync<TestAuthResponse>(
            client,
            "/api/auth/register",
            new
            {
                email = $"owner-{suffix}@example.com",
                password = "OwnerPassword123!",
                fullName = "Integration Owner",
                phoneNumber = TestPhoneNumber(suffix),
                role = UserRoleCode.PropertyOwner
            },
            HttpStatusCode.Created);

        Guid ownedHotelId;
        Guid anotherHotelId;

        using (IServiceScope scope = _factory.Services.CreateScope())
        {
            HotelMarketplaceDbContext dbContext = scope.ServiceProvider.GetRequiredService<HotelMarketplaceDbContext>();

            UserAccount anotherOwner = CreateSeedUser("another-owner");
            HotelProperty ownedHotel = CreateApprovedHotel(registeredOwner.UserId, $"Owned Hotel {suffix}");
            HotelProperty anotherHotel = CreateApprovedHotel(anotherOwner.Id, $"Other Hotel {suffix}");

            dbContext.UserAccounts.Add(anotherOwner);
            dbContext.HotelProperties.AddRange(ownedHotel, anotherHotel);
            await dbContext.SaveChangesAsync();

            ownedHotelId = ownedHotel.Id;
            anotherHotelId = anotherHotel.Id;
        }

        TestAuthResponse loggedInOwner = await PostJsonAsync<TestAuthResponse>(
            client,
            "/api/auth/login",
            new
            {
                email = registeredOwner.Email,
                password = "OwnerPassword123!"
            },
            HttpStatusCode.OK);

        loggedInOwner.HotelIds.Should().Contain(ownedHotelId);
        loggedInOwner.HotelIds.Should().NotContain(anotherHotelId);

        using HttpRequestMessage request = new(HttpMethod.Get, $"/api/owner/hotels/{anotherHotelId}");
        request.Headers.Authorization = Bearer(loggedInOwner.AccessToken);

        HttpResponseMessage response = await client.SendAsync(request);

        response.StatusCode.Should().Be(HttpStatusCode.Forbidden);
    }

    [Fact]
    public async Task BookingLifecycleCreateConfirmCheckInCheckOutCreatesInvoiceAndHousekeepingTask()
    {
        using HttpClient client = _factory.CreateClient();
        SeededHotel seededHotel = await SeedBookableHotelAsync(physicalRoomCount: 1);
        TestAuthResponse customer = await SeedUserAndLoginAsync(client, UserRoleCode.Customer, "customer");
        TestAuthResponse receptionist = await SeedUserAndLoginAsync(
            client,
            UserRoleCode.Receptionist,
            "receptionist",
            seededHotel.HotelId);

        BookingDto booking = await CreateBookingAsync(client, customer.AccessToken, seededHotel);

        DemoPaymentResultDto demoPayment = await PostJsonAsync<DemoPaymentResultDto>(
            client,
            $"/api/bookings/{booking.Id}/demo-payment",
            new { amount = booking.TotalAmount },
            HttpStatusCode.OK,
            customer.AccessToken);

        demoPayment.Status.Should().Be("processed");
        demoPayment.Provider.Should().Be("DEMO");

        FrontDeskBookingDto checkedIn = await PostJsonAsync<FrontDeskBookingDto>(
            client,
            $"/api/hotels/{seededHotel.HotelId}/front-desk/bookings/{booking.Id}/check-in",
            new
            {
                physicalRoomIds = new[] { seededHotel.PhysicalRoomIds.Single() },
                guestFullName = "Booking Guest",
                identityDocumentNumber = "ID123456"
            },
            HttpStatusCode.OK,
            receptionist.AccessToken);

        checkedIn.Status.Should().Be(BookingStatus.CheckedIn);

        FrontDeskBookingDto checkedOut = await PostJsonAsync<FrontDeskBookingDto>(
            client,
            $"/api/hotels/{seededHotel.HotelId}/front-desk/bookings/{booking.Id}/check-out",
            new
            {
                confirmPayAtPropertyCollection = false,
                cashCollectedAmount = 0m
            },
            HttpStatusCode.OK,
            receptionist.AccessToken);

        checkedOut.Status.Should().Be(BookingStatus.CheckedOut);
        checkedOut.InvoiceId.Should().NotBeNull();

        using IServiceScope scope = _factory.Services.CreateScope();
        HotelMarketplaceDbContext dbContext = scope.ServiceProvider.GetRequiredService<HotelMarketplaceDbContext>();

        Invoice invoice = await dbContext.Invoices
            .IgnoreQueryFilters()
            .SingleAsync(entity => entity.BookingId == booking.Id);
        invoice.RoomAmount.Should().Be(booking.TotalAmount);

        HousekeepingTask housekeepingTask = await dbContext.HousekeepingTasks
            .IgnoreQueryFilters()
            .SingleAsync(entity => entity.BookingId == booking.Id);
        housekeepingTask.PhysicalRoomId.Should().Be(seededHotel.PhysicalRoomIds.Single());
        housekeepingTask.Status.Should().Be(HousekeepingTaskStatus.Open);

        PhysicalRoom room = await dbContext.PhysicalRooms
            .IgnoreQueryFilters()
            .SingleAsync(entity => entity.Id == seededHotel.PhysicalRoomIds.Single());
        room.Status.Should().Be(RoomOperationalStatus.Dirty);
    }

    [Fact]
    public async Task ConcurrentBookingRequestsForLastRoomCreateOnlyOneReservation()
    {
        using HttpClient client = _factory.CreateClient();
        SeededHotel seededHotel = await SeedBookableHotelAsync(physicalRoomCount: 1);
        TestAuthResponse customer = await SeedUserAndLoginAsync(client, UserRoleCode.Customer, "overbooking-customer");

        const int attemptCount = 8;

        Task<HttpStatusCode>[] attempts = Enumerable.Range(0, attemptCount)
            .Select(_ => SendCreateBookingAttemptAsync(client, customer.AccessToken, seededHotel))
            .ToArray();

        HttpStatusCode[] statusCodes = await Task.WhenAll(attempts);

        statusCodes.Count(statusCode => statusCode == HttpStatusCode.Created).Should().Be(1);
        statusCodes.Count(statusCode => statusCode is HttpStatusCode.Conflict or (HttpStatusCode)423)
            .Should()
            .Be(attemptCount - 1);

        using IServiceScope scope = _factory.Services.CreateScope();
        HotelMarketplaceDbContext dbContext = scope.ServiceProvider.GetRequiredService<HotelMarketplaceDbContext>();

        int activeReservations = await (
            from bookingRoom in dbContext.BookingRooms.IgnoreQueryFilters()
            join booking in dbContext.Bookings.IgnoreQueryFilters()
                on bookingRoom.BookingId equals booking.Id
            where booking.HotelId == seededHotel.HotelId &&
                bookingRoom.RoomTypeId == seededHotel.RoomTypeId &&
                booking.Status == BookingStatus.PendingPayment
            select booking.Id)
            .CountAsync();

        activeReservations.Should().Be(1);
    }

    [Fact]
    public async Task PayAtPropertyBookingIsConfirmedAndConcurrentCollectionsCannotExceedBalance()
    {
        using HttpClient client = _factory.CreateClient();
        SeededHotel hotel = await SeedBookableHotelAsync(physicalRoomCount: 1);
        TestAuthResponse customer = await SeedUserAndLoginAsync(client, UserRoleCode.Customer, "pay-at-property-customer");
        TestAuthResponse receptionist = await SeedUserAndLoginAsync(
            client,
            UserRoleCode.Receptionist,
            "pay-at-property-receptionist",
            hotel.HotelId);
        DateOnly checkInDate = DateOnly.FromDateTime(DateTime.UtcNow.Date).AddDays(5);

        BookingDto booking = await PostJsonAsync<BookingDto>(
            client,
            "/api/bookings",
            new
            {
                hotelId = hotel.HotelId,
                roomTypeId = hotel.RoomTypeId,
                checkInDate,
                checkOutDate = checkInDate.AddDays(2),
                roomCount = 1,
                guestCount = 1,
                guestFullName = "Property Payment Guest",
                guestPhone = "0901234567",
                paymentMode = PaymentMode.PayAtProperty
            },
            HttpStatusCode.Created,
            customer.AccessToken);

        booking.Status.Should().Be(BookingStatus.Confirmed);
        booking.PaymentMode.Should().Be(PaymentMode.PayAtProperty);
        booking.PaymentExpiresAtUtc.Should().BeNull();

        using (IServiceScope scope = _factory.Services.CreateScope())
        {
            HotelMarketplaceDbContext dbContext = scope.ServiceProvider.GetRequiredService<HotelMarketplaceDbContext>();
            (await dbContext.PaymentTransactions.IgnoreQueryFilters().CountAsync(payment => payment.BookingId == booking.Id))
                .Should().Be(0);
            CommissionRecord commission = await dbContext.CommissionRecords
                .IgnoreQueryFilters()
                .SingleAsync(record => record.BookingId == booking.Id);
            commission.Status.Should().Be(CommissionStatus.Receivable);
        }

        decimal firstAmount = decimal.Round(booking.TotalAmount / 2m, 2, MidpointRounding.AwayFromZero);
        PaymentCollectionSummaryDto partial = await PostJsonAsync<PaymentCollectionSummaryDto>(
            client,
            $"/api/hotels/{hotel.HotelId}/front-desk/bookings/{booking.Id}/payment-collections",
            new
            {
                amount = firstAmount,
                method = PaymentCollectionMethod.Cash,
                collectedAtUtc = DateTime.UtcNow,
                reference = $"PARTIAL-{booking.Id:N}",
                note = "First partial collection"
            },
            HttpStatusCode.Created,
            receptionist.AccessToken);
        partial.Status.Should().Be(PaymentCollectionStatus.Partial);

        decimal remaining = booking.TotalAmount - firstAmount;
        Task<HttpResponseMessage>[] attempts = Enumerable.Range(1, 2)
            .Select(index => SendPaymentCollectionAttemptAsync(
                client,
                receptionist.AccessToken,
                hotel.HotelId,
                booking.Id,
                remaining,
                $"FINAL-{index}-{booking.Id:N}"))
            .ToArray();
        HttpResponseMessage[] responses = await Task.WhenAll(attempts);
        responses.Count(response => response.StatusCode == HttpStatusCode.Created).Should().Be(1);
        responses.Count(response => response.StatusCode is HttpStatusCode.BadRequest or (HttpStatusCode)423).Should().Be(1);
        foreach (HttpResponseMessage response in responses)
        {
            response.Dispose();
        }

        PaymentCollectionSummaryDto completed = await GetJsonAsync<PaymentCollectionSummaryDto>(
            client,
            $"/api/hotels/{hotel.HotelId}/front-desk/bookings/{booking.Id}/payment-collections",
            HttpStatusCode.OK,
            receptionist.AccessToken);
        completed.Status.Should().Be(PaymentCollectionStatus.Completed);
        completed.CollectedAmount.Should().Be(booking.TotalAmount);
        completed.RemainingBalance.Should().Be(0);
        completed.Collections.Should().HaveCount(2);
    }

    [Fact]
    public async Task DemoPaymentRejectsAmountMismatchAndForeignCustomer()
    {
        using HttpClient client = _factory.CreateClient();
        SeededHotel hotel = await SeedBookableHotelAsync(physicalRoomCount: 1);
        TestAuthResponse bookingCustomer = await SeedUserAndLoginAsync(
            client,
            UserRoleCode.Customer,
            "demo-payment-owner");
        TestAuthResponse foreignCustomer = await SeedUserAndLoginAsync(
            client,
            UserRoleCode.Customer,
            "demo-payment-foreign");
        BookingDto booking = await CreateBookingAsync(client, bookingCustomer.AccessToken, hotel);

        using HttpResponseMessage amountMismatch = await SendDemoPaymentAsync(
            client,
            bookingCustomer.AccessToken,
            booking.Id,
            booking.TotalAmount - 1m);
        amountMismatch.StatusCode.Should().Be(HttpStatusCode.Conflict);
        (await amountMismatch.Content.ReadAsStringAsync()).Should().Contain("Payment.AmountMismatch");

        using HttpResponseMessage foreignAttempt = await SendDemoPaymentAsync(
            client,
            foreignCustomer.AccessToken,
            booking.Id,
            booking.TotalAmount);
        foreignAttempt.StatusCode.Should().Be(HttpStatusCode.Forbidden);

        using IServiceScope scope = _factory.Services.CreateScope();
        HotelMarketplaceDbContext dbContext = scope.ServiceProvider.GetRequiredService<HotelMarketplaceDbContext>();
        (await dbContext.PaymentTransactions.IgnoreQueryFilters().CountAsync(entity => entity.BookingId == booking.Id))
            .Should().Be(0);
    }

    [Fact]
    public async Task ConcurrentDemoPaymentIsIdempotentAndCreatesSingleFinancialRecordSet()
    {
        using HttpClient client = _factory.CreateClient();
        SeededHotel hotel = await SeedBookableHotelAsync(physicalRoomCount: 1);
        TestAuthResponse customer = await SeedUserAndLoginAsync(
            client,
            UserRoleCode.Customer,
            "concurrent-demo-payment");
        BookingDto booking = await CreateBookingAsync(client, customer.AccessToken, hotel);

        HttpResponseMessage[] responses = await Task.WhenAll(
            SendDemoPaymentAsync(client, customer.AccessToken, booking.Id, booking.TotalAmount),
            SendDemoPaymentAsync(client, customer.AccessToken, booking.Id, booking.TotalAmount));

        responses.Should().OnlyContain(response => response.StatusCode == HttpStatusCode.OK);
        List<DemoPaymentResultDto> results = new();
        foreach (HttpResponseMessage response in responses)
        {
            DemoPaymentResultDto? result = await response.Content.ReadFromJsonAsync<DemoPaymentResultDto>(JsonOptions);
            result.Should().NotBeNull();
            results.Add(result!);
        }
        List<string> expectedStatuses = ["processed", "duplicate"];
        results.Select(result => result.Status).Should().BeEquivalentTo(expectedStatuses);
        results.Should().OnlyContain(result => result.Provider == "DEMO" && result.Amount == booking.TotalAmount);

        foreach (HttpResponseMessage response in responses)
        {
            response.Dispose();
        }

        using IServiceScope scope = _factory.Services.CreateScope();
        HotelMarketplaceDbContext dbContext = scope.ServiceProvider.GetRequiredService<HotelMarketplaceDbContext>();
        (await dbContext.PaymentTransactions.IgnoreQueryFilters().CountAsync(entity => entity.BookingId == booking.Id))
            .Should().Be(1);
        (await dbContext.CommissionRecords.IgnoreQueryFilters().CountAsync(entity => entity.BookingId == booking.Id))
            .Should().Be(1);
        (await dbContext.AuditRecords.IgnoreQueryFilters().CountAsync(entity =>
            entity.ActionType == "ConfirmDemoPayment" && entity.TargetEntityId == results[0].PaymentTransactionId))
            .Should().Be(1);
        (await dbContext.NotificationRecords.IgnoreQueryFilters().CountAsync(entity =>
            entity.EventType == "DemoPaymentConfirmed" && entity.RelatedEntityId == booking.Id))
            .Should().Be(1);
    }

    [Fact]
    public async Task DemoPaymentAfterDeadlineExpiresBookingWithoutCreatingTransaction()
    {
        using HttpClient client = _factory.CreateClient();
        SeededHotel hotel = await SeedBookableHotelAsync(physicalRoomCount: 1);
        TestAuthResponse customer = await SeedUserAndLoginAsync(
            client,
            UserRoleCode.Customer,
            "expired-demo-payment");
        BookingDto booking = await CreateBookingAsync(client, customer.AccessToken, hotel);

        using (IServiceScope setupScope = _factory.Services.CreateScope())
        {
            HotelMarketplaceDbContext setupContext = setupScope.ServiceProvider.GetRequiredService<HotelMarketplaceDbContext>();
            await setupContext.Bookings
                .IgnoreQueryFilters()
                .Where(entity => entity.Id == booking.Id)
                .ExecuteUpdateAsync(setters => setters.SetProperty(
                    entity => entity.PaymentExpiresAtUtc,
                    DateTime.UtcNow.AddMinutes(-1)));
        }

        using HttpResponseMessage response = await SendDemoPaymentAsync(
            client,
            customer.AccessToken,
            booking.Id,
            booking.TotalAmount);

        response.StatusCode.Should().Be(HttpStatusCode.Conflict);
        (await response.Content.ReadAsStringAsync()).Should().Contain("Payment.PaymentExpired");

        using IServiceScope verificationScope = _factory.Services.CreateScope();
        HotelMarketplaceDbContext dbContext = verificationScope.ServiceProvider.GetRequiredService<HotelMarketplaceDbContext>();
        Booking expiredBooking = await dbContext.Bookings.IgnoreQueryFilters().SingleAsync(entity => entity.Id == booking.Id);
        expiredBooking.Status.Should().Be(BookingStatus.Expired);
        (await dbContext.PaymentTransactions.IgnoreQueryFilters().AnyAsync(entity => entity.BookingId == booking.Id))
            .Should().BeFalse();
    }

    [Fact]
    public async Task ExpirationBatchProcessesDueBookingIdsWithoutSpanEvaluationFailure()
    {
        using HttpClient client = _factory.CreateClient();
        SeededHotel hotel = await SeedBookableHotelAsync(physicalRoomCount: 1);
        TestAuthResponse customer = await SeedUserAndLoginAsync(
            client,
            UserRoleCode.Customer,
            "expiration-batch");
        BookingDto booking = await CreateBookingAsync(client, customer.AccessToken, hotel);

        using IServiceScope scope = _factory.Services.CreateScope();
        HotelMarketplaceDbContext dbContext = scope.ServiceProvider.GetRequiredService<HotelMarketplaceDbContext>();
        await dbContext.Bookings
            .IgnoreQueryFilters()
            .Where(entity => entity.Id == booking.Id)
            .ExecuteUpdateAsync(setters => setters.SetProperty(
                entity => entity.PaymentExpiresAtUtc,
                DateTime.UtcNow.AddMinutes(-1)));

        IExpiredBookingService expirationService =
            scope.ServiceProvider.GetRequiredService<IExpiredBookingService>();
        ExpireUnpaidBookingsResult result = await expirationService.ExpireUnpaidBookingsAsync(
            100,
            CancellationToken.None);

        result.ExpiredBookings.Should().Contain(entity => entity.BookingId == booking.Id);
        Booking expiredBooking = await dbContext.Bookings
            .IgnoreQueryFilters()
            .SingleAsync(entity => entity.Id == booking.Id);
        expiredBooking.Status.Should().Be(BookingStatus.Expired);
    }

    [Fact]
    public async Task LegacyPayOsAndPaymentLinkRoutesAreNotExposed()
    {
        using HttpClient client = _factory.CreateClient();

        using HttpResponseMessage webhookResponse = await client.PostAsJsonAsync(
            "/api/payments/payos/webhook",
            new { });
        using HttpResponseMessage returnResponse = await client.GetAsync("/api/payments/payos/return");
        using HttpResponseMessage paymentLinkResponse = await client.PostAsJsonAsync(
            $"/api/bookings/{Guid.NewGuid()}/payment-link",
            new { });

        webhookResponse.StatusCode.Should().Be(HttpStatusCode.NotFound);
        returnResponse.StatusCode.Should().Be(HttpStatusCode.NotFound);
        paymentLinkResponse.StatusCode.Should().Be(HttpStatusCode.NotFound);
    }

    [Fact]
    public async Task CancellingUnpaidBookingReleasesInventoryWithoutCreatingRefund()
    {
        using HttpClient client = _factory.CreateClient();
        SeededHotel hotel = await SeedBookableHotelAsync(physicalRoomCount: 1);
        TestAuthResponse customer = await SeedUserAndLoginAsync(
            client,
            UserRoleCode.Customer,
            "unpaid-cancellation");
        BookingDto booking = await CreateBookingAsync(client, customer.AccessToken, hotel);

        BookingCancellationQuoteDto quote = await GetJsonAsync<BookingCancellationQuoteDto>(
            client,
            $"/api/bookings/{booking.Id}/cancellation-quote",
            HttpStatusCode.OK,
            customer.AccessToken);
        quote.CanCancel.Should().BeTrue();
        quote.IsPaid.Should().BeFalse();
        quote.EstimatedRefundAmount.Should().Be(0);

        BookingCancellationResultDto cancellation = await PostJsonAsync<BookingCancellationResultDto>(
            client,
            $"/api/bookings/{booking.Id}/cancel",
            new { reason = "Travel plans changed" },
            HttpStatusCode.OK,
            customer.AccessToken);
        cancellation.BookingStatus.Should().Be(BookingStatus.Cancelled);
        cancellation.RefundRecordId.Should().BeNull();

        BookingDto replacementBooking = await CreateBookingAsync(client, customer.AccessToken, hotel);
        replacementBooking.Status.Should().Be(BookingStatus.PendingPayment);

        using IServiceScope scope = _factory.Services.CreateScope();
        HotelMarketplaceDbContext dbContext = scope.ServiceProvider.GetRequiredService<HotelMarketplaceDbContext>();
        (await dbContext.RefundRecords.IgnoreQueryFilters().AnyAsync(refund => refund.BookingId == booking.Id))
            .Should().BeFalse();
    }

    [Fact]
    public async Task CancellingPaidBookingWithinPolicyCreatesSinglePendingRefund()
    {
        using HttpClient client = _factory.CreateClient();
        SeededHotel hotel = await SeedBookableHotelAsync(physicalRoomCount: 1);
        TestAuthResponse customer = await SeedUserAndLoginAsync(
            client,
            UserRoleCode.Customer,
            "paid-cancellation");

        using (IServiceScope setupScope = _factory.Services.CreateScope())
        {
            HotelMarketplaceDbContext setupContext = setupScope.ServiceProvider.GetRequiredService<HotelMarketplaceDbContext>();
            setupContext.CancellationPolicies.Add(
                new CancellationPolicy(Guid.NewGuid(), hotel.HotelId, "Flexible 48 hours", 48, 80m));
            await setupContext.SaveChangesAsync();
        }

        BookingDto booking = await CreateBookingAsync(client, customer.AccessToken, hotel);
        await PostJsonAsync<DemoPaymentResultDto>(
            client,
            $"/api/bookings/{booking.Id}/demo-payment",
            new { amount = booking.TotalAmount },
            HttpStatusCode.OK,
            customer.AccessToken);

        BookingCancellationQuoteDto quote = await GetJsonAsync<BookingCancellationQuoteDto>(
            client,
            $"/api/bookings/{booking.Id}/cancellation-quote",
            HttpStatusCode.OK,
            customer.AccessToken);
        quote.IsPaid.Should().BeTrue();
        quote.IsWithinFreeCancellationWindow.Should().BeTrue();
        quote.EstimatedRefundAmount.Should().Be(booking.TotalAmount * 0.8m);

        BookingCancellationResultDto cancellation = await PostJsonAsync<BookingCancellationResultDto>(
            client,
            $"/api/bookings/{booking.Id}/cancel",
            new { reason = "Unable to travel" },
            HttpStatusCode.OK,
            customer.AccessToken);
        cancellation.RefundRequestedAmount.Should().Be(booking.TotalAmount * 0.8m);
        cancellation.RefundStatus.Should().Be(RefundStatus.PendingReview);

        IReadOnlyCollection<BookingDto> customerBookings = await GetJsonAsync<IReadOnlyCollection<BookingDto>>(
            client,
            "/api/bookings/my",
            HttpStatusCode.OK,
            customer.AccessToken);
        BookingDto cancelledBooking = customerBookings.Single(entity => entity.Id == booking.Id);
        cancelledBooking.RefundStatus.Should().Be(RefundStatus.PendingReview);
        cancelledBooking.RefundRequestedAmount.Should().Be(booking.TotalAmount * 0.8m);

        using IServiceScope verificationScope = _factory.Services.CreateScope();
        HotelMarketplaceDbContext dbContext = verificationScope.ServiceProvider.GetRequiredService<HotelMarketplaceDbContext>();
        RefundRecord refund = await dbContext.RefundRecords
            .IgnoreQueryFilters()
            .SingleAsync(entity => entity.BookingId == booking.Id);
        refund.RequestedAmount.Should().Be(booking.TotalAmount * 0.8m);
        (await dbContext.PaymentTransactions.IgnoreQueryFilters().SingleAsync(entity => entity.BookingId == booking.Id))
            .Status.Should().Be(PaymentStatus.Paid);
    }

    [Fact]
    public async Task ForeignCustomerCannotReadQuoteOrCancelBooking()
    {
        using HttpClient client = _factory.CreateClient();
        SeededHotel hotel = await SeedBookableHotelAsync(physicalRoomCount: 1);
        TestAuthResponse owner = await SeedUserAndLoginAsync(client, UserRoleCode.Customer, "cancel-owner");
        TestAuthResponse foreignCustomer = await SeedUserAndLoginAsync(client, UserRoleCode.Customer, "cancel-foreign");
        BookingDto booking = await CreateBookingAsync(client, owner.AccessToken, hotel);

        using HttpRequestMessage quoteRequest = new(
            HttpMethod.Get,
            $"/api/bookings/{booking.Id}/cancellation-quote");
        quoteRequest.Headers.Authorization = Bearer(foreignCustomer.AccessToken);
        using HttpResponseMessage quoteResponse = await client.SendAsync(quoteRequest);
        quoteResponse.StatusCode.Should().Be(HttpStatusCode.Forbidden);

        using HttpRequestMessage cancelRequest = new(
            HttpMethod.Post,
            $"/api/bookings/{booking.Id}/cancel");
        cancelRequest.Headers.Authorization = Bearer(foreignCustomer.AccessToken);
        cancelRequest.Content = JsonContent.Create(new { reason = "Unauthorized cancellation" }, options: JsonOptions);
        using HttpResponseMessage cancelResponse = await client.SendAsync(cancelRequest);
        cancelResponse.StatusCode.Should().Be(HttpStatusCode.Forbidden);
    }

    [Fact]
    public async Task ConcurrentPaymentAndCancellationLeaveOneConsistentCancelledOutcome()
    {
        using HttpClient client = _factory.CreateClient();
        SeededHotel hotel = await SeedBookableHotelAsync(physicalRoomCount: 1);
        TestAuthResponse customer = await SeedUserAndLoginAsync(
            client,
            UserRoleCode.Customer,
            "payment-cancellation-race");
        BookingDto booking = await CreateBookingAsync(client, customer.AccessToken, hotel);

        Task<HttpResponseMessage> paymentTask = SendDemoPaymentAsync(
            client,
            customer.AccessToken,
            booking.Id,
            booking.TotalAmount);
        Task<HttpResponseMessage> cancellationTask = SendCancellationAsync(
            client,
            customer.AccessToken,
            booking.Id,
            "Concurrent cancellation request");

        HttpResponseMessage[] responses = await Task.WhenAll(paymentTask, cancellationTask);
        using HttpResponseMessage paymentResponse = responses[0];
        using HttpResponseMessage cancellationResponse = responses[1];

        cancellationResponse.StatusCode.Should().Be(HttpStatusCode.OK);
        paymentResponse.StatusCode.Should().BeOneOf(HttpStatusCode.OK, HttpStatusCode.Conflict);

        using IServiceScope scope = _factory.Services.CreateScope();
        HotelMarketplaceDbContext dbContext = scope.ServiceProvider.GetRequiredService<HotelMarketplaceDbContext>();
        Booking storedBooking = await dbContext.Bookings
            .IgnoreQueryFilters()
            .SingleAsync(entity => entity.Id == booking.Id);
        storedBooking.Status.Should().Be(BookingStatus.Cancelled);
        storedBooking.CancellationReason.Should().Be("Concurrent cancellation request");
        (await dbContext.PaymentTransactions.IgnoreQueryFilters().CountAsync(entity => entity.BookingId == booking.Id))
            .Should().BeLessThanOrEqualTo(1);
        (await dbContext.AuditRecords.IgnoreQueryFilters().CountAsync(entity =>
            entity.ActionType == "CancelBooking" && entity.TargetEntityId == booking.Id)).Should().Be(1);
        (await dbContext.RefundRecords.IgnoreQueryFilters().AnyAsync(entity => entity.BookingId == booking.Id))
            .Should().BeFalse();
    }

    [Fact]
    public async Task NoShowRequiresElapsedWindowAndCreatesOperationalEvidence()
    {
        using HttpClient client = _factory.CreateClient();
        SeededHotel hotel = await SeedBookableHotelAsync(physicalRoomCount: 1);
        TestAuthResponse receptionist = await SeedUserAndLoginAsync(
            client,
            UserRoleCode.Receptionist,
            "no-show-receptionist",
            hotel.HotelId);
        TestAuthResponse customer = await SeedUserAndLoginAsync(client, UserRoleCode.Customer, "no-show-customer");
        BookingDto futureBooking = await CreateBookingAsync(client, customer.AccessToken, hotel);
        await PostJsonAsync<DemoPaymentResultDto>(
            client,
            $"/api/bookings/{futureBooking.Id}/demo-payment",
            new { amount = futureBooking.TotalAmount },
            HttpStatusCode.OK,
            customer.AccessToken);

        using HttpRequestMessage earlyRequest = new(
            HttpMethod.Post,
            $"/api/hotels/{hotel.HotelId}/front-desk/bookings/{futureBooking.Id}/no-show");
        earlyRequest.Headers.Authorization = Bearer(receptionist.AccessToken);
        earlyRequest.Content = JsonContent.Create(
            new { reason = "Guest did not arrive" },
            options: JsonOptions);
        using HttpResponseMessage earlyResponse = await client.SendAsync(earlyRequest);
        earlyResponse.StatusCode.Should().Be(HttpStatusCode.Conflict);
        (await earlyResponse.Content.ReadAsStringAsync()).Should().Contain("FrontDesk.NoShowWindowNotReached");

        Guid eligibleBookingId;
        using (IServiceScope setupScope = _factory.Services.CreateScope())
        {
            HotelMarketplaceDbContext setupContext = setupScope.ServiceProvider.GetRequiredService<HotelMarketplaceDbContext>();
            DateOnly checkInDate = DateOnly.FromDateTime(DateTime.UtcNow.Date).AddDays(-2);
            Booking eligibleBooking = new(
                Guid.NewGuid(),
                $"NS{Guid.NewGuid():N}"[..32],
                customer.UserId,
                hotel.HotelId,
                checkInDate,
                checkInDate.AddDays(3),
                PaymentMode.PayAtProperty,
                BookingSource.Marketplace,
                100m,
                "No Show Guest",
                "0900000000");
            eligibleBooking.AddRoom(new BookingRoom(
                Guid.NewGuid(),
                eligibleBooking.Id,
                hotel.RoomTypeId,
                1,
                100m,
                3));
            setupContext.Bookings.Add(eligibleBooking);
            await setupContext.SaveChangesAsync();
            eligibleBookingId = eligibleBooking.Id;
        }

        FrontDeskBookingDto noShow = await PostJsonAsync<FrontDeskBookingDto>(
            client,
            $"/api/hotels/{hotel.HotelId}/front-desk/bookings/{eligibleBookingId}/no-show",
            new { reason = "Guest did not arrive within the operational window" },
            HttpStatusCode.OK,
            receptionist.AccessToken);
        noShow.Status.Should().Be(BookingStatus.NoShow);

        using IServiceScope verificationScope = _factory.Services.CreateScope();
        HotelMarketplaceDbContext verificationContext = verificationScope.ServiceProvider.GetRequiredService<HotelMarketplaceDbContext>();
        Booking storedBooking = await verificationContext.Bookings
            .IgnoreQueryFilters()
            .SingleAsync(entity => entity.Id == eligibleBookingId);
        storedBooking.NoShowReason.Should().Be("Guest did not arrive within the operational window");
        storedBooking.NoShowAtUtc.Should().NotBeNull();
        (await verificationContext.AuditRecords.IgnoreQueryFilters().AnyAsync(record =>
            record.ActionType == "MarkBookingNoShow" && record.TargetEntityId == eligibleBookingId)).Should().BeTrue();
        (await verificationContext.NotificationRecords.IgnoreQueryFilters().AnyAsync(record =>
            record.EventType == "BookingMarkedNoShow" && record.RelatedEntityId == eligibleBookingId)).Should().BeTrue();
    }

    [Fact]
    public async Task ConcurrentMarketplaceAndWalkInRequestsCannotCommitTheLastRoomTwice()
    {
        using HttpClient client = _factory.CreateClient();
        SeededHotel hotel = await SeedBookableHotelAsync(physicalRoomCount: 1);
        TestAuthResponse customer = await SeedUserAndLoginAsync(client, UserRoleCode.Customer, "cross-channel-customer");
        TestAuthResponse receptionist = await SeedUserAndLoginAsync(
            client,
            UserRoleCode.Receptionist,
            "cross-channel-receptionist",
            hotel.HotelId);
        DateOnly checkInDate = DateOnly.FromDateTime(DateTime.UtcNow.Date).AddDays(25);
        DateOnly checkOutDate = checkInDate.AddDays(2);

        Task<HttpStatusCode> marketplaceAttempt = SendCreateBookingAttemptAsync(
            client,
            customer.AccessToken,
            hotel,
            checkInDate,
            checkOutDate);
        Task<HttpStatusCode> walkInAttempt = SendWalkInBookingAttemptAsync(
            client,
            receptionist.AccessToken,
            hotel,
            checkInDate,
            checkOutDate);

        HttpStatusCode[] statusCodes = await Task.WhenAll(marketplaceAttempt, walkInAttempt);

        statusCodes.Count(statusCode => statusCode == HttpStatusCode.Created).Should().Be(1);
        statusCodes.Count(statusCode => statusCode is HttpStatusCode.Conflict or (HttpStatusCode)423)
            .Should()
            .Be(1);

        using IServiceScope scope = _factory.Services.CreateScope();
        HotelMarketplaceDbContext dbContext = scope.ServiceProvider.GetRequiredService<HotelMarketplaceDbContext>();

        int committedQuantity = await (
            from bookingRoom in dbContext.BookingRooms.IgnoreQueryFilters()
            join booking in dbContext.Bookings.IgnoreQueryFilters()
                on bookingRoom.BookingId equals booking.Id
            where booking.HotelId == hotel.HotelId &&
                bookingRoom.RoomTypeId == hotel.RoomTypeId &&
                booking.CheckInDate < checkOutDate &&
                booking.CheckOutDate > checkInDate &&
                (booking.Status == BookingStatus.PendingPayment ||
                    booking.Status == BookingStatus.Confirmed ||
                    booking.Status == BookingStatus.CheckedIn)
            select bookingRoom.Quantity)
            .SumAsync();

        committedQuantity.Should().Be(1);
    }

    [Fact]
    public async Task WalkInWithoutRoomAssignmentCreatesConfirmedBookingForAnonymousCustomer()
    {
        using HttpClient client = _factory.CreateClient();
        SeededHotel hotel = await SeedBookableHotelAsync(physicalRoomCount: 2);
        TestAuthResponse receptionist = await SeedUserAndLoginAsync(
            client,
            UserRoleCode.Receptionist,
            "unassigned-walk-in-receptionist",
            hotel.HotelId);
        DateOnly checkInDate = DateOnly.FromDateTime(DateTime.UtcNow.Date).AddDays(3);

        FrontDeskBookingDto result = await PostJsonAsync<FrontDeskBookingDto>(
            client,
            $"/api/hotels/{hotel.HotelId}/front-desk/walk-in-bookings",
            new
            {
                roomTypeId = hotel.RoomTypeId,
                roomCount = 1,
                physicalRoomIds = Array.Empty<Guid>(),
                checkInDate,
                checkOutDate = checkInDate.AddDays(2),
                guestCount = 2,
                guestFullName = "Future Walk In Guest",
                guestPhone = "0987654321",
                identityDocumentNumber = "WALKIN-FUTURE",
                cashCollectedAmount = 200m
            },
            HttpStatusCode.Created,
            receptionist.AccessToken);

        result.Status.Should().Be(BookingStatus.Confirmed);
        result.AssignedRooms.Should().BeEmpty();
        result.GuestStayRecordId.Should().BeNull();

        using IServiceScope scope = _factory.Services.CreateScope();
        HotelMarketplaceDbContext dbContext = scope.ServiceProvider.GetRequiredService<HotelMarketplaceDbContext>();
        Booking booking = await dbContext.Bookings.IgnoreQueryFilters().SingleAsync(entity => entity.Id == result.BookingId);
        booking.CustomerUserAccountId.Should().Be(HotelMarketplace.Domain.Security.SeededUserAccountIds.AnonymousWalkInCustomer);
        booking.Source.Should().Be(BookingSource.WalkIn);
        booking.PaymentMode.Should().Be(PaymentMode.PayAtProperty);
        booking.PaymentExpiresAtUtc.Should().BeNull();
        (await dbContext.PaymentCollectionRecords.IgnoreQueryFilters().SingleAsync(entity => entity.BookingId == booking.Id))
            .Amount.Should().Be(booking.TotalAmount);
    }

    [Fact]
    public async Task AnonymousWalkInSystemAccountCannotLoginOrBeManagedAsAUser()
    {
        using HttpClient client = _factory.CreateClient();
        TestAuthResponse administrator = await SeedUserAndLoginAsync(
            client,
            UserRoleCode.PlatformAdministrator,
            "system-account-admin");

        using HttpResponseMessage loginResponse = await client.PostAsJsonAsync(
            "/api/auth/login",
            new { email = "anonymous-walk-in@system.local", password = "any-password" },
            JsonOptions);
        loginResponse.StatusCode.Should().Be(HttpStatusCode.Unauthorized);

        IReadOnlyCollection<HotelMarketplace.Application.PlatformAdmin.Dtos.AdminUserDto> users =
            await GetJsonAsync<IReadOnlyCollection<HotelMarketplace.Application.PlatformAdmin.Dtos.AdminUserDto>>(
                client,
                "/api/platform-admin/users?searchTerm=anonymous-walk-in",
                HttpStatusCode.OK,
                administrator.AccessToken);
        users.Should().BeEmpty();

        using HttpRequestMessage suspendRequest = new(
            HttpMethod.Post,
            $"/api/platform-admin/users/{HotelMarketplace.Domain.Security.SeededUserAccountIds.AnonymousWalkInCustomer}/suspend");
        suspendRequest.Headers.Authorization = Bearer(administrator.AccessToken);
        using HttpResponseMessage suspendResponse = await client.SendAsync(suspendRequest);
        suspendResponse.StatusCode.Should().Be(HttpStatusCode.NotFound);
    }

    [Fact]
    public async Task WalkInRejectsCashAmountThatDoesNotMatchServerCalculatedTotal()
    {
        using HttpClient client = _factory.CreateClient();
        SeededHotel hotel = await SeedBookableHotelAsync(physicalRoomCount: 1);
        TestAuthResponse receptionist = await SeedUserAndLoginAsync(
            client,
            UserRoleCode.Receptionist,
            "incorrect-walk-in-cash-receptionist",
            hotel.HotelId);
        DateOnly checkInDate = DateOnly.FromDateTime(DateTime.UtcNow.Date).AddDays(4);

        using HttpRequestMessage request = new(
            HttpMethod.Post,
            $"/api/hotels/{hotel.HotelId}/front-desk/walk-in-bookings");
        request.Headers.Authorization = Bearer(receptionist.AccessToken);
        request.Content = JsonContent.Create(
            new
            {
                roomTypeId = hotel.RoomTypeId,
                roomCount = 1,
                physicalRoomIds = Array.Empty<Guid>(),
                checkInDate,
                checkOutDate = checkInDate.AddDays(2),
                guestCount = 1,
                guestFullName = "Incorrect Cash Guest",
                guestPhone = "0987654321",
                cashCollectedAmount = 199m
            },
            options: JsonOptions);

        using HttpResponseMessage response = await client.SendAsync(request);

        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
        (await response.Content.ReadAsStringAsync()).Should().Contain("FrontDesk.IncorrectCashAmount");
    }

    [Fact]
    public async Task ConcurrentOverlappingDateRangesUseTheSameRoomTypeInventoryLock()
    {
        using HttpClient client = _factory.CreateClient();
        SeededHotel hotel = await SeedBookableHotelAsync(physicalRoomCount: 1);
        TestAuthResponse customer = await SeedUserAndLoginAsync(client, UserRoleCode.Customer, "overlap-window-customer");
        DateOnly firstCheckIn = DateOnly.FromDateTime(DateTime.UtcNow.Date).AddDays(40);
        DateOnly firstCheckOut = firstCheckIn.AddDays(3);
        DateOnly secondCheckIn = firstCheckIn.AddDays(2);
        DateOnly secondCheckOut = secondCheckIn.AddDays(3);

        HttpStatusCode[] statusCodes = await Task.WhenAll(
            SendCreateBookingAttemptAsync(
                client,
                customer.AccessToken,
                hotel,
                firstCheckIn,
                firstCheckOut),
            SendCreateBookingAttemptAsync(
                client,
                customer.AccessToken,
                hotel,
                secondCheckIn,
                secondCheckOut));

        statusCodes.Count(statusCode => statusCode == HttpStatusCode.Created).Should().Be(1);
        statusCodes.Count(statusCode => statusCode is HttpStatusCode.Conflict or (HttpStatusCode)423)
            .Should()
            .Be(1);
    }

    [Fact]
    public async Task PhysicalRoomAvailabilityBlockReducesBookableInventory()
    {
        using HttpClient client = _factory.CreateClient();
        SeededHotel hotel = await SeedBookableHotelAsync(physicalRoomCount: 1);
        TestAuthResponse customer = await SeedUserAndLoginAsync(client, UserRoleCode.Customer, "blocked-room-customer");
        DateOnly checkInDate = DateOnly.FromDateTime(DateTime.UtcNow.Date).AddDays(30);
        DateOnly checkOutDate = checkInDate.AddDays(2);

        using (IServiceScope scope = _factory.Services.CreateScope())
        {
            HotelMarketplaceDbContext dbContext = scope.ServiceProvider.GetRequiredService<HotelMarketplaceDbContext>();
            dbContext.RoomAvailabilities.Add(new RoomAvailability(
                Guid.NewGuid(),
                hotel.HotelId,
                hotel.RoomTypeId,
                checkInDate,
                checkOutDate,
                AvailabilityStatus.Blocked,
                hotel.PhysicalRoomIds.Single(),
                "Integration test inventory block"));
            await dbContext.SaveChangesAsync();
        }

        using HttpRequestMessage request = new(HttpMethod.Post, "/api/bookings");
        request.Headers.Authorization = Bearer(customer.AccessToken);
        request.Content = JsonContent.Create(
            new
            {
                hotelId = hotel.HotelId,
                roomTypeId = hotel.RoomTypeId,
                checkInDate,
                checkOutDate,
                roomCount = 1,
                guestCount = 1,
                guestFullName = "Blocked Room Guest",
                guestPhone = "0900000000",
                paymentMode = PaymentMode.PlatformCollect
            },
            options: JsonOptions);

        using HttpResponseMessage response = await client.SendAsync(request);

        response.StatusCode.Should().Be(HttpStatusCode.Conflict);
        (await response.Content.ReadAsStringAsync()).Should().Contain("Booking.InsufficientAvailability");
    }

    [Fact]
    public async Task AvailabilityCloseAndOpenImmediatelyUpdateMarketplaceProjection()
    {
        using HttpClient client = _factory.CreateClient();
        SeededHotel hotel = await SeedBookableHotelAsync(physicalRoomCount: 1);
        TestAuthResponse owner = await SeedUserAndLoginAsync(
            client,
            UserRoleCode.PropertyOwner,
            "availability-owner",
            hotel.HotelId);
        DateOnly startDate = DateOnly.FromDateTime(DateTime.UtcNow.Date).AddDays(70);
        DateOnly endDate = startDate.AddDays(3);
        string availabilityQuery = $"checkInDate={startDate:yyyy-MM-dd}&checkOutDate={endDate:yyyy-MM-dd}&guestCount=1&roomCount=1";

        IReadOnlyCollection<HotelSearchResultDto> beforeClose = await GetJsonAsync<IReadOnlyCollection<HotelSearchResultDto>>(
            client,
            $"/api/public/hotels?{availabilityQuery}",
            HttpStatusCode.OK);
        beforeClose.Should().Contain(result => result.Id == hotel.HotelId);

        AvailabilityCalendarDto closed = await PostJsonAsync<AvailabilityCalendarDto>(
            client,
            $"/api/hotels/{hotel.HotelId}/availability/changes",
            new
            {
                roomTypeId = hotel.RoomTypeId,
                physicalRoomId = (Guid?)null,
                startDate,
                endDate,
                action = AvailabilityChangeAction.Close,
                reason = "Private event inventory hold"
            },
            HttpStatusCode.OK,
            owner.AccessToken);
        closed.Entries.Should().ContainSingle(entry =>
            entry.Status == AvailabilityStatus.Closed &&
            entry.RoomTypeId == hotel.RoomTypeId &&
            entry.PhysicalRoomId == null);

        IReadOnlyCollection<HotelSearchResultDto> afterClose = await GetJsonAsync<IReadOnlyCollection<HotelSearchResultDto>>(
            client,
            $"/api/public/hotels?{availabilityQuery}",
            HttpStatusCode.OK);
        afterClose.Should().NotContain(result => result.Id == hotel.HotelId);

        AvailabilityCalendarDto opened = await PostJsonAsync<AvailabilityCalendarDto>(
            client,
            $"/api/hotels/{hotel.HotelId}/availability/changes",
            new
            {
                roomTypeId = hotel.RoomTypeId,
                physicalRoomId = (Guid?)null,
                startDate,
                endDate,
                action = AvailabilityChangeAction.Open,
                reason = (string?)null
            },
            HttpStatusCode.OK,
            owner.AccessToken);
        opened.Entries.Should().BeEmpty();

        IReadOnlyCollection<HotelSearchResultDto> afterOpen = await GetJsonAsync<IReadOnlyCollection<HotelSearchResultDto>>(
            client,
            $"/api/public/hotels?{availabilityQuery}",
            HttpStatusCode.OK);
        afterOpen.Should().Contain(result => result.Id == hotel.HotelId);
    }

    [Fact]
    public async Task AvailabilityBlockRejectsActiveBookingWithoutChangingCalendar()
    {
        using HttpClient client = _factory.CreateClient();
        SeededHotel hotel = await SeedBookableHotelAsync(physicalRoomCount: 1);
        TestAuthResponse customer = await SeedUserAndLoginAsync(client, UserRoleCode.Customer, "availability-customer");
        TestAuthResponse owner = await SeedUserAndLoginAsync(
            client,
            UserRoleCode.PropertyOwner,
            "availability-conflict-owner",
            hotel.HotelId);
        BookingDto booking = await CreateBookingAsync(client, customer.AccessToken, hotel);

        using HttpRequestMessage request = new(
            HttpMethod.Post,
            $"/api/hotels/{hotel.HotelId}/availability/changes");
        request.Headers.Authorization = Bearer(owner.AccessToken);
        request.Content = JsonContent.Create(
            new
            {
                roomTypeId = hotel.RoomTypeId,
                physicalRoomId = hotel.PhysicalRoomIds.Single(),
                startDate = booking.CheckInDate,
                endDate = booking.CheckOutDate,
                action = AvailabilityChangeAction.Block,
                reason = "Emergency engineering inspection"
            },
            options: JsonOptions);

        using HttpResponseMessage response = await client.SendAsync(request);
        string responseBody = await response.Content.ReadAsStringAsync();
        response.StatusCode.Should().Be(HttpStatusCode.Conflict, responseBody);
        responseBody.Should().Contain("Availability.ActiveBookingConflict");

        AvailabilityCalendarDto calendar = await GetJsonAsync<AvailabilityCalendarDto>(
            client,
            $"/api/hotels/{hotel.HotelId}/availability?startDate={booking.CheckInDate:yyyy-MM-dd}&endDate={booking.CheckOutDate:yyyy-MM-dd}",
            HttpStatusCode.OK,
            owner.AccessToken);
        calendar.Entries.Should().BeEmpty();
        calendar.ActiveCommitments.Should().ContainSingle(item => item.BookingId == booking.Id);
    }

    [Fact]
    public async Task ReceptionistCanBlockPhysicalRoomButCannotCloseRoomType()
    {
        using HttpClient client = _factory.CreateClient();
        SeededHotel hotel = await SeedBookableHotelAsync(physicalRoomCount: 1);
        TestAuthResponse receptionist = await SeedUserAndLoginAsync(
            client,
            UserRoleCode.Receptionist,
            "availability-receptionist",
            hotel.HotelId);
        DateOnly startDate = DateOnly.FromDateTime(DateTime.UtcNow.Date).AddDays(90);
        DateOnly endDate = startDate.AddDays(2);

        using HttpRequestMessage restrictedRequest = new(
            HttpMethod.Post,
            $"/api/hotels/{hotel.HotelId}/availability/changes");
        restrictedRequest.Headers.Authorization = Bearer(receptionist.AccessToken);
        restrictedRequest.Content = JsonContent.Create(
            new
            {
                roomTypeId = hotel.RoomTypeId,
                physicalRoomId = (Guid?)null,
                startDate,
                endDate,
                action = AvailabilityChangeAction.Close,
                reason = "Receptionist cannot close a room type"
            },
            options: JsonOptions);

        using HttpResponseMessage restrictedResponse = await client.SendAsync(restrictedRequest);
        restrictedResponse.StatusCode.Should().Be(HttpStatusCode.Forbidden);

        AvailabilityCalendarDto blocked = await PostJsonAsync<AvailabilityCalendarDto>(
            client,
            $"/api/hotels/{hotel.HotelId}/availability/changes",
            new
            {
                roomTypeId = hotel.RoomTypeId,
                physicalRoomId = hotel.PhysicalRoomIds.Single(),
                startDate,
                endDate,
                action = AvailabilityChangeAction.Block,
                reason = "Room temporarily held for operational inspection"
            },
            HttpStatusCode.OK,
            receptionist.AccessToken);

        blocked.Entries.Should().ContainSingle(entry =>
            entry.Status == AvailabilityStatus.Blocked &&
            entry.PhysicalRoomId == hotel.PhysicalRoomIds.Single());
    }

    [Fact]
    public async Task ConcurrentOnlineBookingAndAvailabilityBlockCannotBothCommit()
    {
        using HttpClient client = _factory.CreateClient();
        SeededHotel hotel = await SeedBookableHotelAsync(physicalRoomCount: 1);
        TestAuthResponse customer = await SeedUserAndLoginAsync(client, UserRoleCode.Customer, "availability-race-customer");
        TestAuthResponse owner = await SeedUserAndLoginAsync(
            client,
            UserRoleCode.PropertyOwner,
            "availability-race-owner",
            hotel.HotelId);
        DateOnly startDate = DateOnly.FromDateTime(DateTime.UtcNow.Date).AddDays(110);
        DateOnly endDate = startDate.AddDays(2);

        HttpStatusCode[] statusCodes = await Task.WhenAll(
            SendCreateBookingAttemptAsync(
                client,
                customer.AccessToken,
                hotel,
                startDate,
                endDate),
            SendAvailabilityChangeAttemptAsync(
                client,
                owner.AccessToken,
                hotel,
                startDate,
                endDate));

        statusCodes.Count(status => status is HttpStatusCode.Created or HttpStatusCode.OK)
            .Should()
            .Be(1);
        statusCodes.Count(status => status is HttpStatusCode.Conflict or (HttpStatusCode)423)
            .Should()
            .Be(1);
    }

    [Fact]
    public async Task PartialUnblockPreservesRestrictionOutsideSelectedDates()
    {
        using HttpClient client = _factory.CreateClient();
        SeededHotel hotel = await SeedBookableHotelAsync(physicalRoomCount: 1);
        TestAuthResponse owner = await SeedUserAndLoginAsync(
            client,
            UserRoleCode.PropertyOwner,
            "availability-split-owner",
            hotel.HotelId);
        DateOnly blockedStart = DateOnly.FromDateTime(DateTime.UtcNow.Date).AddDays(130);
        DateOnly blockedEnd = blockedStart.AddDays(10);
        DateOnly openStart = blockedStart.AddDays(3);
        DateOnly openEnd = blockedStart.AddDays(6);

        await PostJsonAsync<AvailabilityCalendarDto>(
            client,
            $"/api/hotels/{hotel.HotelId}/availability/changes",
            new
            {
                roomTypeId = hotel.RoomTypeId,
                physicalRoomId = hotel.PhysicalRoomIds.Single(),
                startDate = blockedStart,
                endDate = blockedEnd,
                action = AvailabilityChangeAction.Block,
                reason = "Planned room refurbishment"
            },
            HttpStatusCode.OK,
            owner.AccessToken);

        await PostJsonAsync<AvailabilityCalendarDto>(
            client,
            $"/api/hotels/{hotel.HotelId}/availability/changes",
            new
            {
                roomTypeId = hotel.RoomTypeId,
                physicalRoomId = hotel.PhysicalRoomIds.Single(),
                startDate = openStart,
                endDate = openEnd,
                action = AvailabilityChangeAction.Unblock,
                reason = (string?)null
            },
            HttpStatusCode.OK,
            owner.AccessToken);

        AvailabilityCalendarDto calendar = await GetJsonAsync<AvailabilityCalendarDto>(
            client,
            $"/api/hotels/{hotel.HotelId}/availability" +
                $"?startDate={blockedStart:yyyy-MM-dd}&endDate={blockedEnd:yyyy-MM-dd}" +
                $"&roomTypeId={hotel.RoomTypeId}&physicalRoomId={hotel.PhysicalRoomIds.Single()}",
            HttpStatusCode.OK,
            owner.AccessToken);

        calendar.Entries.Should().HaveCount(2);
        calendar.Entries.Should().Contain(entry =>
            entry.StartDate == blockedStart && entry.EndDate == openStart);
        calendar.Entries.Should().Contain(entry =>
            entry.StartDate == openEnd && entry.EndDate == blockedEnd);
    }

    [Fact]
    public async Task CheckInExpiredBookingReturnsConflict()
    {
        using HttpClient client = _factory.CreateClient();
        SeededHotel seededHotel = await SeedBookableHotelAsync(physicalRoomCount: 1);
        TestAuthResponse customer = await SeedUserAndLoginAsync(client, UserRoleCode.Customer, "expired-booking-customer");
        TestAuthResponse receptionist = await SeedUserAndLoginAsync(
            client,
            UserRoleCode.Receptionist,
            "expired-booking-receptionist",
            seededHotel.HotelId);

        BookingDto booking = await CreateBookingAsync(client, customer.AccessToken, seededHotel);

        using (IServiceScope scope = _factory.Services.CreateScope())
        {
            HotelMarketplaceDbContext dbContext = scope.ServiceProvider.GetRequiredService<HotelMarketplaceDbContext>();
            Booking entity = await dbContext.Bookings
                .IgnoreQueryFilters()
                .SingleAsync(item => item.Id == booking.Id);

            entity.ExpirePaymentHold(entity.PaymentExpiresAtUtc!.Value.AddSeconds(1));
            await dbContext.SaveChangesAsync();
        }

        using HttpRequestMessage request = new(
            HttpMethod.Post,
            $"/api/hotels/{seededHotel.HotelId}/front-desk/bookings/{booking.Id}/check-in");
        request.Headers.Authorization = Bearer(receptionist.AccessToken);
        request.Content = JsonContent.Create(
            new
            {
                physicalRoomIds = new[] { seededHotel.PhysicalRoomIds.Single() },
                guestFullName = "Expired Booking Guest",
                identityDocumentNumber = "EXPIRED123"
            },
            options: JsonOptions);

        using HttpResponseMessage response = await client.SendAsync(request);

        response.StatusCode.Should().Be(HttpStatusCode.Conflict);
        string responseBody = await response.Content.ReadAsStringAsync();
        responseBody.Should().Contain("FrontDesk.InvalidBookingStatusForCheckIn");
    }

    [Fact]
    public async Task ForgedHotelHeaderCannotOverrideRouteScopedAuthorization()
    {
        using HttpClient client = _factory.CreateClient();
        SeededHotel allowedHotel = await SeedBookableHotelAsync(physicalRoomCount: 1);
        SeededHotel forbiddenHotel = await SeedBookableHotelAsync(physicalRoomCount: 1);
        TestAuthResponse receptionist = await SeedUserAndLoginAsync(
            client,
            UserRoleCode.Receptionist,
            "forged-header-receptionist",
            allowedHotel.HotelId);

        using HttpRequestMessage request = new(
            HttpMethod.Get,
            $"/api/hotels/{forbiddenHotel.HotelId}/housekeeping/tasks");
        request.Headers.Authorization = Bearer(receptionist.AccessToken);
        request.Headers.Add("X-Hotel-Id", allowedHotel.HotelId.ToString());

        using HttpResponseMessage response = await client.SendAsync(request);

        response.StatusCode.Should().Be(HttpStatusCode.Forbidden);
    }

    [Fact]
    public async Task UnassignedPlatformAdministratorCannotAccessHotelOperations()
    {
        using HttpClient client = _factory.CreateClient();
        SeededHotel hotel = await SeedBookableHotelAsync(physicalRoomCount: 1);
        TestAuthResponse administrator = await SeedUserAndLoginAsync(
            client,
            UserRoleCode.PlatformAdministrator,
            "unassigned-platform-administrator");

        using HttpRequestMessage request = new(
            HttpMethod.Get,
            $"/api/hotels/{hotel.HotelId}/front-desk/physical-rooms");
        request.Headers.Authorization = Bearer(administrator.AccessToken);

        using HttpResponseMessage response = await client.SendAsync(request);

        response.StatusCode.Should().Be(HttpStatusCode.Forbidden);
    }

    [Fact]
    public async Task HotelScopedRoleMustMatchTheRoleAssignedAtTheRequestedHotel()
    {
        using HttpClient client = _factory.CreateClient();
        SeededHotel receptionistHotel = await SeedBookableHotelAsync(physicalRoomCount: 1);
        SeededHotel managerHotel = await SeedBookableHotelAsync(physicalRoomCount: 1);
        string suffix = Guid.NewGuid().ToString("N");
        string email = $"mixed-role-{suffix}@example.com";
        const string password = "IntegrationPassword123!";

        using (IServiceScope scope = _factory.Services.CreateScope())
        {
            HotelMarketplaceDbContext dbContext = scope.ServiceProvider.GetRequiredService<HotelMarketplaceDbContext>();
            HotelMarketplace.Application.Authentication.IPasswordHasher passwordHasher =
                scope.ServiceProvider.GetRequiredService<HotelMarketplace.Application.Authentication.IPasswordHasher>();

            UserAccount user = new(
                Guid.NewGuid(),
                email,
                passwordHasher.HashPassword(password),
                "Mixed Role User");

            dbContext.UserAccounts.Add(user);
            dbContext.UserAccountRoles.AddRange(
                new UserAccountRole(Guid.NewGuid(), user.Id, SeededRoleIds.Receptionist),
                new UserAccountRole(Guid.NewGuid(), user.Id, SeededRoleIds.HotelManager));
            dbContext.HotelStaffAssignments.AddRange(
                new HotelStaffAssignment(
                    Guid.NewGuid(),
                    user.Id,
                    receptionistHotel.HotelId,
                    SeededRoleIds.Receptionist,
                    user.Id),
                new HotelStaffAssignment(
                    Guid.NewGuid(),
                    user.Id,
                    managerHotel.HotelId,
                    SeededRoleIds.HotelManager,
                    user.Id));
            await dbContext.SaveChangesAsync();
        }

        TestAuthResponse userSession = await LoginAsync(client, email, password);

        using HttpRequestMessage receptionistHotelRequest = new(
            HttpMethod.Get,
            $"/api/operations/hotels/{receptionistHotel.HotelId}/staff");
        receptionistHotelRequest.Headers.Authorization = Bearer(userSession.AccessToken);
        using HttpResponseMessage receptionistHotelResponse = await client.SendAsync(receptionistHotelRequest);

        using HttpRequestMessage managerHotelRequest = new(
            HttpMethod.Get,
            $"/api/operations/hotels/{managerHotel.HotelId}/staff");
        managerHotelRequest.Headers.Authorization = Bearer(userSession.AccessToken);
        using HttpResponseMessage managerHotelResponse = await client.SendAsync(managerHotelRequest);

        receptionistHotelResponse.StatusCode.Should().Be(HttpStatusCode.Forbidden);
        managerHotelResponse.StatusCode.Should().Be(HttpStatusCode.OK);
    }

    [Fact]
    public async Task RevokedHotelAssignmentInvalidatesAccessBeforeJwtExpires()
    {
        using HttpClient client = _factory.CreateClient();
        SeededHotel hotel = await SeedBookableHotelAsync(physicalRoomCount: 1);
        TestAuthResponse receptionist = await SeedUserAndLoginAsync(
            client,
            UserRoleCode.Receptionist,
            "revoked-receptionist",
            hotel.HotelId);

        using (IServiceScope scope = _factory.Services.CreateScope())
        {
            HotelMarketplaceDbContext dbContext = scope.ServiceProvider.GetRequiredService<HotelMarketplaceDbContext>();
            HotelStaffAssignment assignment = await dbContext.HotelStaffAssignments
                .IgnoreQueryFilters()
                .SingleAsync(item => item.UserAccountId == receptionist.UserId && item.HotelId == hotel.HotelId);

            assignment.Revoke();
            await dbContext.SaveChangesAsync();
        }

        using HttpRequestMessage request = new(
            HttpMethod.Get,
            $"/api/hotels/{hotel.HotelId}/front-desk/physical-rooms");
        request.Headers.Authorization = Bearer(receptionist.AccessToken);

        using HttpResponseMessage response = await client.SendAsync(request);

        response.StatusCode.Should().Be(HttpStatusCode.Forbidden);
    }

    [Fact]
    public async Task ConcurrentCheckInRequestsAssignPhysicalRoomOnlyOnce()
    {
        using HttpClient client = _factory.CreateClient();
        SeededHotel seededHotel = await SeedBookableHotelAsync(physicalRoomCount: 1);
        TestAuthResponse customer = await SeedUserAndLoginAsync(client, UserRoleCode.Customer, "double-checkin-customer");
        TestAuthResponse receptionist = await SeedUserAndLoginAsync(
            client,
            UserRoleCode.Receptionist,
            "double-checkin-receptionist",
            seededHotel.HotelId);

        BookingDto booking = await CreateBookingAsync(client, customer.AccessToken, seededHotel);

        await PostJsonAsync<DemoPaymentResultDto>(
            client,
            $"/api/bookings/{booking.Id}/demo-payment",
            new { amount = booking.TotalAmount },
            HttpStatusCode.OK,
            customer.AccessToken);

        const int attemptCount = 4;
        Task<HttpStatusCode>[] attempts = Enumerable.Range(0, attemptCount)
            .Select(index => SendCheckInAttemptAsync(
                client,
                receptionist.AccessToken,
                seededHotel.HotelId,
                booking.Id,
                seededHotel.PhysicalRoomIds.Single(),
                $"Double Check In Guest {index}"))
            .ToArray();

        HttpStatusCode[] statusCodes = await Task.WhenAll(attempts);

        statusCodes.Count(statusCode => statusCode == HttpStatusCode.OK).Should().Be(1);
        statusCodes.Count(statusCode => statusCode is HttpStatusCode.Conflict or (HttpStatusCode)423)
            .Should()
            .Be(attemptCount - 1);

        using IServiceScope scope = _factory.Services.CreateScope();
        HotelMarketplaceDbContext dbContext = scope.ServiceProvider.GetRequiredService<HotelMarketplaceDbContext>();

        int activeAssignments = await dbContext.BookingRoomAssignments
            .IgnoreQueryFilters()
            .CountAsync(assignment => assignment.BookingId == booking.Id && assignment.Status == RecordStatus.Active);

        activeAssignments.Should().Be(1);
    }

    [Fact]
    public async Task PublicOwnerOperationsFrontDeskHousekeepingMaintenanceAndAdminApisSmokeTest()
    {
        using HttpClient client = _factory.CreateClient();
        string suffix = Guid.NewGuid().ToString("N");

        TestAuthResponse owner = await PostJsonAsync<TestAuthResponse>(
            client,
            "/api/auth/register",
            new
            {
                email = $"owner-smoke-{suffix}@example.com",
                password = "OwnerPassword123!",
                fullName = "Demo Property Owner",
                phoneNumber = TestPhoneNumber(suffix),
                role = UserRoleCode.PropertyOwner
            },
            HttpStatusCode.Created);

        TestAuthResponse customer = await SeedUserAndLoginAsync(client, UserRoleCode.Customer, "smoke-customer");
        TestAuthResponse admin = await SeedUserAndLoginAsync(client, UserRoleCode.PlatformAdministrator, "smoke-admin");

        HotelDto hotel = await PostJsonAsync<HotelDto>(
            client,
            "/api/owner/hotels",
            new
            {
                name = "Harbor Suites Saigon",
                city = "Ho Chi Minh City",
                addressLine = "99 Nguyen Hue Boulevard",
                contactEmail = $"qa-harbor-suites-{suffix}@example.com",
                contactPhone = "0907654321",
                description = "Demo property for end-to-end validation."
            },
            HttpStatusCode.Created,
            owner.AccessToken);

        owner = await LoginAsync(client, owner.Email, "OwnerPassword123!");

        IReadOnlyCollection<HotelDto> ownerHotels = await GetJsonAsync<IReadOnlyCollection<HotelDto>>(
            client,
            "/api/owner/hotels",
            HttpStatusCode.OK,
            owner.AccessToken);
        ownerHotels.Should().Contain(item => item.Id == hotel.Id);

        HotelDto ownerHotelDetail = await GetJsonAsync<HotelDto>(
            client,
            $"/api/owner/hotels/{hotel.Id}",
            HttpStatusCode.OK,
            owner.AccessToken);
        ownerHotelDetail.ApprovalStatus.Should().Be(HotelApprovalStatus.PendingReview);

        HotelDto updatedHotel = await SendJsonAsync<HotelDto>(
            client,
            HttpMethod.Put,
            $"/api/owner/hotels/{hotel.Id}",
            new
            {
                name = "Harbor Suites Saigon Riverside",
                city = "Ho Chi Minh City",
                addressLine = "100 Nguyen Hue Boulevard",
                contactEmail = $"qa-harbor-suites-updated-{suffix}@example.com",
                contactPhone = "0907654321",
                description = "Updated demo property."
            },
            HttpStatusCode.OK,
            owner.AccessToken);
        updatedHotel.Name.Should().Be("Harbor Suites Saigon Riverside");

        RoomTypeDto temporaryRoomType = await PostJsonAsync<RoomTypeDto>(
            client,
            $"/api/owner/hotels/{hotel.Id}/room-types",
            new
            {
                name = "Temporary",
                adultCapacity = 1,
                childCapacity = 0,
                basePricePerNight = 50m,
                description = "Temporary room type"
            },
            HttpStatusCode.Created,
            owner.AccessToken);

        await SendNoContentAsync(
            client,
            HttpMethod.Delete,
            $"/api/owner/hotels/{hotel.Id}/room-types/{temporaryRoomType.Id}",
            HttpStatusCode.NoContent,
            owner.AccessToken);

        RoomTypeDto roomType = await PostJsonAsync<RoomTypeDto>(
            client,
            $"/api/owner/hotels/{hotel.Id}/room-types",
            new
            {
                name = "Deluxe Smoke",
                adultCapacity = 2,
                childCapacity = 1,
                basePricePerNight = 120m,
                description = "Deluxe smoke room"
            },
            HttpStatusCode.Created,
            owner.AccessToken);

        RoomTypeDto updatedRoomType = await SendJsonAsync<RoomTypeDto>(
            client,
            HttpMethod.Put,
            $"/api/owner/hotels/{hotel.Id}/room-types/{roomType.Id}",
            new
            {
                name = "Deluxe Smoke Updated",
                adultCapacity = 2,
                childCapacity = 1,
                basePricePerNight = 130m,
                description = "Updated deluxe smoke room"
            },
            HttpStatusCode.OK,
            owner.AccessToken);
        updatedRoomType.BasePricePerNight.Should().Be(130m);

        PhysicalRoomDto firstRoom = await PostJsonAsync<PhysicalRoomDto>(
            client,
            $"/api/owner/hotels/{hotel.Id}/physical-rooms",
            new
            {
                roomTypeId = roomType.Id,
                roomNumber = $"S{suffix[..6]}1",
                initialStatus = RoomOperationalStatus.Available
            },
            HttpStatusCode.Created,
            owner.AccessToken);

        PhysicalRoomDto secondRoom = await PostJsonAsync<PhysicalRoomDto>(
            client,
            $"/api/owner/hotels/{hotel.Id}/physical-rooms",
            new
            {
                roomTypeId = roomType.Id,
                roomNumber = $"S{suffix[..6]}2",
                initialStatus = RoomOperationalStatus.Available
            },
            HttpStatusCode.Created,
            owner.AccessToken);

        PhysicalRoomDto renamedSecondRoom = await SendJsonAsync<PhysicalRoomDto>(
            client,
            HttpMethod.Put,
            $"/api/owner/hotels/{hotel.Id}/physical-rooms/{secondRoom.Id}",
            new
            {
                roomNumber = $"{secondRoom.RoomNumber}A",
                status = RoomOperationalStatus.Available
            },
            HttpStatusCode.OK,
            owner.AccessToken);
        renamedSecondRoom.RoomNumber.Should().EndWith("A");

        IReadOnlyCollection<PhysicalRoomDto> ownerRooms = await GetJsonAsync<IReadOnlyCollection<PhysicalRoomDto>>(
            client,
            $"/api/owner/hotels/{hotel.Id}/physical-rooms?roomTypeId={roomType.Id}",
            HttpStatusCode.OK,
            owner.AccessToken);
        ownerRooms.Should().HaveCount(2);

        IReadOnlyCollection<AdminHotelDto> pendingHotels = await GetJsonAsync<IReadOnlyCollection<AdminHotelDto>>(
            client,
            "/api/platform-admin/hotels/pending-review",
            HttpStatusCode.OK,
            admin.AccessToken);
        pendingHotels.Should().Contain(item => item.Id == hotel.Id);

        AdminHotelDto approvedHotel = await PostJsonAsync<AdminHotelDto>(
            client,
            $"/api/platform-admin/hotels/{hotel.Id}/approve",
            new { },
            HttpStatusCode.OK,
            admin.AccessToken);
        approvedHotel.ApprovalStatus.Should().Be(HotelApprovalStatus.Approved);
        approvedHotel.PublicationStatus.Should().Be(PublicationStatus.Published);

        AdminHotelDto commissionHotel = await SendJsonAsync<AdminHotelDto>(
            client,
            HttpMethod.Put,
            $"/api/platform-admin/hotels/{hotel.Id}/commission-rate",
            new { commissionRate = 0.12m },
            HttpStatusCode.OK,
            admin.AccessToken);
        commissionHotel.DefaultCommissionRate.Should().Be(0.12m);

        DateOnly checkInDate = DateOnly.FromDateTime(DateTime.UtcNow.Date).AddDays(30);
        DateOnly checkOutDate = checkInDate.AddDays(2);
        string availabilityQuery = $"checkInDate={checkInDate:yyyy-MM-dd}&checkOutDate={checkOutDate:yyyy-MM-dd}&guestCount=2&roomCount=1";

        IReadOnlyCollection<HotelSearchResultDto> searchResults = await GetJsonAsync<IReadOnlyCollection<HotelSearchResultDto>>(
            client,
            $"/api/public/hotels?location=Ho%20Chi%20Minh&{availabilityQuery}",
            HttpStatusCode.OK);
        searchResults.Should().Contain(item => item.Id == hotel.Id);

        HotelDetailDto publicDetail = await GetJsonAsync<HotelDetailDto>(
            client,
            $"/api/public/hotels/{hotel.Id}?{availabilityQuery}",
            HttpStatusCode.OK);
        publicDetail.AvailableRoomTypes.Should().Contain(item => item.Id == roomType.Id);

        BookingDto booking = await PostJsonAsync<BookingDto>(
            client,
            "/api/bookings",
            new
            {
                hotelId = hotel.Id,
                roomTypeId = roomType.Id,
                checkInDate,
                checkOutDate,
                roomCount = 1,
                guestCount = 2,
                guestFullName = "Smoke Booking Guest",
                guestPhone = "0912345678",
                paymentMode = PaymentMode.PlatformCollect
            },
            HttpStatusCode.Created,
            customer.AccessToken);

        IReadOnlyCollection<BookingDto> customerBookings = await GetJsonAsync<IReadOnlyCollection<BookingDto>>(
            client,
            "/api/bookings/my",
            HttpStatusCode.OK,
            customer.AccessToken);
        customerBookings.Should().Contain(item => item.Id == booking.Id);

        CustomerProfileDto profile = await GetJsonAsync<CustomerProfileDto>(
            client,
            "/api/customer/account/profile",
            HttpStatusCode.OK,
            customer.AccessToken);
        profile.Email.Should().Be(customer.Email);

        string updatedCustomerPhoneNumber = TestPhoneNumber("8291");
        CustomerProfileDto updatedProfile = await SendJsonAsync<CustomerProfileDto>(
            client,
            HttpMethod.Put,
            "/api/customer/account/profile",
            new
            {
                fullName = "Updated Smoke Customer",
                phoneNumber = updatedCustomerPhoneNumber
            },
            HttpStatusCode.OK,
            customer.AccessToken);
        updatedProfile.FullName.Should().Be("Updated Smoke Customer");
        updatedProfile.PhoneNumber.Should().Be(updatedCustomerPhoneNumber);

        DemoPaymentResultDto demoPayment = await PostJsonAsync<DemoPaymentResultDto>(
            client,
            $"/api/bookings/{booking.Id}/demo-payment",
            new { amount = booking.TotalAmount },
            HttpStatusCode.OK,
            customer.AccessToken);
        demoPayment.Status.Should().Be("processed");
        demoPayment.Provider.Should().Be("DEMO");

        TestAuthResponse receptionist = await SeedUserAndLoginAsync(client, UserRoleCode.Receptionist, "smoke-receptionist", hotel.Id);
        TestAuthResponse housekeeper = await SeedUserAndLoginAsync(client, UserRoleCode.HousekeepingStaff, "smoke-housekeeper", hotel.Id);
        TestAuthResponse maintenance = await SeedUserAndLoginAsync(client, UserRoleCode.MaintenanceStaff, "smoke-maintenance", hotel.Id);

        IReadOnlyCollection<RoomTypeDto> operationRoomTypes = await GetJsonAsync<IReadOnlyCollection<RoomTypeDto>>(
            client,
            $"/api/operations/hotels/{hotel.Id}/room-types",
            HttpStatusCode.OK,
            receptionist.AccessToken);
        operationRoomTypes.Should().Contain(item => item.Id == roomType.Id && item.Name == "Deluxe Smoke Updated");

        FrontDeskBookingDto checkedIn = await PostJsonAsync<FrontDeskBookingDto>(
            client,
            $"/api/hotels/{hotel.Id}/front-desk/bookings/{booking.Id}/check-in",
            new
            {
                physicalRoomIds = new[] { firstRoom.Id },
                guestFullName = "Smoke Booking Guest",
                identityDocumentNumber = "IDSMOKE"
            },
            HttpStatusCode.OK,
            receptionist.AccessToken);
        checkedIn.Status.Should().Be(BookingStatus.CheckedIn);

        FrontDeskBookingDto checkedOut = await PostJsonAsync<FrontDeskBookingDto>(
            client,
            $"/api/hotels/{hotel.Id}/front-desk/bookings/{booking.Id}/check-out",
            new
            {
                confirmPayAtPropertyCollection = false,
                cashCollectedAmount = 0m
            },
            HttpStatusCode.OK,
            receptionist.AccessToken);
        checkedOut.Status.Should().Be(BookingStatus.CheckedOut);

        IReadOnlyCollection<HousekeepingTaskDto> housekeepingTasks = await GetJsonAsync<IReadOnlyCollection<HousekeepingTaskDto>>(
            client,
            $"/api/hotels/{hotel.Id}/housekeeping/tasks?status={HousekeepingTaskStatus.Open}",
            HttpStatusCode.OK,
            housekeeper.AccessToken);
        HousekeepingTaskDto housekeepingTask = housekeepingTasks.Single(item => item.PhysicalRoomId == firstRoom.Id);

        IReadOnlyCollection<HotelStaffMemberDto> operationStaff = await GetJsonAsync<IReadOnlyCollection<HotelStaffMemberDto>>(
            client,
            $"/api/operations/hotels/{hotel.Id}/staff",
            HttpStatusCode.OK,
            owner.AccessToken);
        operationStaff.Should().Contain(item => item.UserAccountId == housekeeper.UserId && item.Role == UserRoleCode.HousekeepingStaff);
        operationStaff.Should().Contain(item => item.UserAccountId == maintenance.UserId && item.Role == UserRoleCode.MaintenanceStaff);

        HousekeepingTaskDto assignedHousekeepingTask = await SendJsonAsync<HousekeepingTaskDto>(
            client,
            HttpMethod.Patch,
            $"/api/hotels/{hotel.Id}/housekeeping/tasks/{housekeepingTask.Id}/assignee",
            new { assignedToUserAccountId = housekeeper.UserId },
            HttpStatusCode.OK,
            owner.AccessToken);
        assignedHousekeepingTask.AssignedToUserAccountId.Should().Be(housekeeper.UserId);

        HousekeepingTaskDto taskInProgress = await SendJsonAsync<HousekeepingTaskDto>(
            client,
            HttpMethod.Patch,
            $"/api/hotels/{hotel.Id}/housekeeping/tasks/{housekeepingTask.Id}/status",
            new { status = HousekeepingTaskStatus.InProgress },
            HttpStatusCode.OK,
            housekeeper.AccessToken);
        taskInProgress.Status.Should().Be(HousekeepingTaskStatus.InProgress);

        HousekeepingTaskDto completedTask = await SendJsonAsync<HousekeepingTaskDto>(
            client,
            HttpMethod.Patch,
            $"/api/hotels/{hotel.Id}/housekeeping/tasks/{housekeepingTask.Id}/status",
            new { status = HousekeepingTaskStatus.Completed },
            HttpStatusCode.OK,
            housekeeper.AccessToken);
        completedTask.RoomStatus.Should().Be(RoomOperationalStatus.Available);

        MaintenanceRequestDto maintenanceRequest = await PostJsonAsync<MaintenanceRequestDto>(
            client,
            $"/api/hotels/{hotel.Id}/maintenance/requests",
            new
            {
                physicalRoomId = firstRoom.Id,
                description = "Smoke maintenance request",
                severity = MaintenanceSeverity.Medium,
                targetRoomStatus = RoomOperationalStatus.Maintenance
            },
            HttpStatusCode.Created,
            housekeeper.AccessToken);
        maintenanceRequest.Status.Should().Be(MaintenanceStatus.Open);
        maintenanceRequest.RoomStatus.Should().Be(RoomOperationalStatus.Maintenance);

        IReadOnlyCollection<MaintenanceRequestDto> maintenanceRequests = await GetJsonAsync<IReadOnlyCollection<MaintenanceRequestDto>>(
            client,
            $"/api/hotels/{hotel.Id}/maintenance/requests?status={MaintenanceStatus.Open}",
            HttpStatusCode.OK,
            maintenance.AccessToken);
        maintenanceRequests.Should().Contain(item => item.Id == maintenanceRequest.Id);

        MaintenanceRequestDto assignedMaintenanceRequest = await SendJsonAsync<MaintenanceRequestDto>(
            client,
            HttpMethod.Patch,
            $"/api/hotels/{hotel.Id}/maintenance/requests/{maintenanceRequest.Id}/assignee",
            new { assignedToUserAccountId = maintenance.UserId },
            HttpStatusCode.OK,
            owner.AccessToken);
        assignedMaintenanceRequest.AssignedToUserAccountId.Should().Be(maintenance.UserId);

        MaintenanceRequestDto repairInProgress = await SendJsonAsync<MaintenanceRequestDto>(
            client,
            HttpMethod.Patch,
            $"/api/hotels/{hotel.Id}/maintenance/requests/{maintenanceRequest.Id}/status",
            new { status = MaintenanceStatus.InProgress },
            HttpStatusCode.OK,
            maintenance.AccessToken);
        repairInProgress.Status.Should().Be(MaintenanceStatus.InProgress);

        MaintenanceRequestDto repairResolved = await SendJsonAsync<MaintenanceRequestDto>(
            client,
            HttpMethod.Patch,
            $"/api/hotels/{hotel.Id}/maintenance/requests/{maintenanceRequest.Id}/status",
            new { status = MaintenanceStatus.Resolved },
            HttpStatusCode.OK,
            maintenance.AccessToken);
        repairResolved.RoomStatus.Should().Be(RoomOperationalStatus.Available);

        FrontDeskBookingDto walkInBooking = await PostJsonAsync<FrontDeskBookingDto>(
            client,
            $"/api/hotels/{hotel.Id}/front-desk/walk-in-bookings",
            new
            {
                roomTypeId = roomType.Id,
                roomCount = 1,
                physicalRoomIds = new[] { firstRoom.Id },
                checkInDate = DateOnly.FromDateTime(DateTime.UtcNow.Date),
                checkOutDate = DateOnly.FromDateTime(DateTime.UtcNow.Date).AddDays(1),
                guestCount = 1,
                guestFullName = "Walk In Guest",
                guestPhone = "0987654321",
                identityDocumentNumber = "WALKIN",
                cashCollectedAmount = 130m
            },
            HttpStatusCode.Created,
            receptionist.AccessToken);
        walkInBooking.Status.Should().Be(BookingStatus.CheckedIn);

        IReadOnlyCollection<AdminPaymentTransactionDto> paymentTransactions = await GetJsonAsync<IReadOnlyCollection<AdminPaymentTransactionDto>>(
            client,
            "/api/platform-admin/payments",
            HttpStatusCode.OK,
            admin.AccessToken);
        AdminPaymentTransactionDto paymentTransaction = paymentTransactions.Single(item => item.BookingId == booking.Id);
        paymentTransaction.Status.Should().Be(PaymentStatus.Paid);

        AdminPaymentTransactionDto reconciledPayment = await SendJsonAsync<AdminPaymentTransactionDto>(
            client,
            HttpMethod.Patch,
            $"/api/platform-admin/payments/{paymentTransaction.Id}/reconciliation",
            new { status = ReconciliationStatus.Reconciled },
            HttpStatusCode.OK,
            admin.AccessToken);
        reconciledPayment.ReconciliationStatus.Should().Be(ReconciliationStatus.Reconciled);

        IReadOnlyCollection<AdminFinanceSummaryDto> financeSummary = await GetJsonAsync<IReadOnlyCollection<AdminFinanceSummaryDto>>(
            client,
            $"/api/platform-admin/finance/summary?hotelId={hotel.Id}&fromDate={checkInDate:yyyy-MM-dd}&toDate={checkOutDate:yyyy-MM-dd}",
            HttpStatusCode.OK,
            admin.AccessToken);
        financeSummary.Should().Contain(item => item.HotelId == hotel.Id && item.SuccessfulBookingCount >= 1);

        AdminSettlementDto settlement = await PostJsonAsync<AdminSettlementDto>(
            client,
            "/api/platform-admin/settlements",
            new
            {
                hotelId = hotel.Id,
                paymentMode = PaymentMode.PlatformCollect,
                fromDate = checkInDate,
                toDate = checkOutDate,
                adminNote = "Smoke settlement"
            },
            HttpStatusCode.Created,
            admin.AccessToken);
        settlement.Items.Should().NotBeEmpty();

        IReadOnlyCollection<AdminSettlementDto> settlements = await GetJsonAsync<IReadOnlyCollection<AdminSettlementDto>>(
            client,
            $"/api/platform-admin/settlements?hotelId={hotel.Id}&status={SettlementStatus.Pending}",
            HttpStatusCode.OK,
            admin.AccessToken);
        settlements.Should().Contain(item => item.Id == settlement.Id);

        AdminSettlementDto settled = await SendJsonAsync<AdminSettlementDto>(
            client,
            HttpMethod.Patch,
            $"/api/platform-admin/settlements/{settlement.Id}/status",
            new
            {
                status = SettlementStatus.Settled,
                settledAmount = settlement.ExpectedAmount,
                settlementDateUtc = DateTime.UtcNow,
                reference = $"SMOKE-{settlement.Id:N}",
                adminNote = "Smoke settled"
            },
            HttpStatusCode.OK,
            admin.AccessToken);
        settled.Status.Should().Be(SettlementStatus.Settled);

        Guid refundId = await SeedRefundAsync(hotel.Id, booking.Id);

        IReadOnlyCollection<AdminRefundDto> refunds = await GetJsonAsync<IReadOnlyCollection<AdminRefundDto>>(
            client,
            $"/api/platform-admin/refunds?status={RefundStatus.PendingReview}",
            HttpStatusCode.OK,
            admin.AccessToken);
        refunds.Should().Contain(item => item.Id == refundId);

        AdminRefundDto approvedRefund = await SendJsonAsync<AdminRefundDto>(
            client,
            HttpMethod.Patch,
            $"/api/platform-admin/refunds/{refundId}/status",
            new
            {
                status = RefundStatus.Approved,
                approvedAmount = 50m
            },
            HttpStatusCode.OK,
            admin.AccessToken);
        approvedRefund.Status.Should().Be(RefundStatus.Approved);

        AdminRefundDto processedRefund = await SendJsonAsync<AdminRefundDto>(
            client,
            HttpMethod.Patch,
            $"/api/platform-admin/refunds/{refundId}/status",
            new
            {
                status = RefundStatus.Processed,
                approvedAmount = (decimal?)null
            },
            HttpStatusCode.OK,
            admin.AccessToken);
        processedRefund.Status.Should().Be(RefundStatus.Processed);

        HotelDto hotelToReject = await PostJsonAsync<HotelDto>(
            client,
            "/api/owner/hotels",
            new
            {
                name = "Harbor Suites Rejection Review",
                city = "Da Nang",
                addressLine = "1 Bach Dang Riverside",
                contactEmail = $"harbor-rejection-review-{suffix}@example.com",
                contactPhone = "0901112222",
                description = "Demo property for hotel rejection workflow validation."
            },
            HttpStatusCode.Created,
            owner.AccessToken);

        AdminHotelDto rejectedHotel = await PostJsonAsync<AdminHotelDto>(
            client,
            $"/api/platform-admin/hotels/{hotelToReject.Id}/reject",
            new { reason = "Demo rejection reason" },
            HttpStatusCode.OK,
            admin.AccessToken);
        rejectedHotel.ApprovalStatus.Should().Be(HotelApprovalStatus.Rejected);
    }

    private static async Task<BookingDto> CreateBookingAsync(
        HttpClient client,
        string accessToken,
        SeededHotel seededHotel)
    {
        DateOnly checkInDate = DateOnly.FromDateTime(DateTime.UtcNow.Date).AddDays(10);
        DateOnly checkOutDate = checkInDate.AddDays(2);

        return await PostJsonAsync<BookingDto>(
            client,
            "/api/bookings",
            new
            {
                hotelId = seededHotel.HotelId,
                roomTypeId = seededHotel.RoomTypeId,
                checkInDate,
                checkOutDate,
                roomCount = 1,
                guestCount = 2,
                guestFullName = "Booking Guest",
                guestPhone = "0900000000",
                paymentMode = PaymentMode.PlatformCollect
            },
            HttpStatusCode.Created,
            accessToken);
    }

    private static async Task<HttpStatusCode> SendCreateBookingAttemptAsync(
        HttpClient client,
        string accessToken,
        SeededHotel seededHotel)
    {
        DateOnly checkInDate = DateOnly.FromDateTime(DateTime.UtcNow.Date).AddDays(20);
        DateOnly checkOutDate = checkInDate.AddDays(1);

        return await SendCreateBookingAttemptAsync(
            client,
            accessToken,
            seededHotel,
            checkInDate,
            checkOutDate);
    }

    private static async Task<HttpStatusCode> SendCreateBookingAttemptAsync(
        HttpClient client,
        string accessToken,
        SeededHotel seededHotel,
        DateOnly checkInDate,
        DateOnly checkOutDate)
    {

        using HttpRequestMessage request = new(HttpMethod.Post, "/api/bookings");
        request.Headers.Authorization = Bearer(accessToken);
        request.Content = JsonContent.Create(
            new
            {
                hotelId = seededHotel.HotelId,
                roomTypeId = seededHotel.RoomTypeId,
                checkInDate,
                checkOutDate,
                roomCount = 1,
                guestCount = 1,
                guestFullName = "Concurrent Guest",
                guestPhone = "0911111111",
                paymentMode = PaymentMode.PlatformCollect
            },
            options: JsonOptions);

        HttpResponseMessage response = await client.SendAsync(request);
        return response.StatusCode;
    }

    private static async Task<HttpResponseMessage> SendDemoPaymentAsync(
        HttpClient client,
        string accessToken,
        Guid bookingId,
        decimal amount)
    {
        using HttpRequestMessage request = new(
            HttpMethod.Post,
            $"/api/bookings/{bookingId}/demo-payment");
        request.Headers.Authorization = Bearer(accessToken);
        request.Content = JsonContent.Create(new { amount }, options: JsonOptions);
        return await client.SendAsync(request);
    }

    private static async Task<HttpResponseMessage> SendPaymentCollectionAttemptAsync(
        HttpClient client,
        string accessToken,
        Guid hotelId,
        Guid bookingId,
        decimal amount,
        string reference)
    {
        using HttpRequestMessage request = new(
            HttpMethod.Post,
            $"/api/hotels/{hotelId}/front-desk/bookings/{bookingId}/payment-collections");
        request.Headers.Authorization = Bearer(accessToken);
        request.Content = JsonContent.Create(
            new
            {
                amount,
                method = PaymentCollectionMethod.Cash,
                collectedAtUtc = DateTime.UtcNow,
                reference,
                note = "Concurrent final collection"
            },
            options: JsonOptions);

        return await client.SendAsync(request);
    }

    private static async Task<HttpStatusCode> SendAvailabilityChangeAttemptAsync(
        HttpClient client,
        string accessToken,
        SeededHotel hotel,
        DateOnly startDate,
        DateOnly endDate)
    {
        using HttpRequestMessage request = new(
            HttpMethod.Post,
            $"/api/hotels/{hotel.HotelId}/availability/changes");
        request.Headers.Authorization = Bearer(accessToken);
        request.Content = JsonContent.Create(
            new
            {
                roomTypeId = hotel.RoomTypeId,
                physicalRoomId = hotel.PhysicalRoomIds.Single(),
                startDate,
                endDate,
                action = AvailabilityChangeAction.Block,
                reason = "Concurrent inventory control"
            },
            options: JsonOptions);

        using HttpResponseMessage response = await client.SendAsync(request);
        return response.StatusCode;
    }

    private static async Task<HttpResponseMessage> SendCancellationAsync(
        HttpClient client,
        string accessToken,
        Guid bookingId,
        string reason)
    {
        using HttpRequestMessage request = new(
            HttpMethod.Post,
            $"/api/bookings/{bookingId}/cancel");
        request.Headers.Authorization = Bearer(accessToken);
        request.Content = JsonContent.Create(new { reason }, options: JsonOptions);
        return await client.SendAsync(request);
    }

    private static async Task<HttpStatusCode> SendWalkInBookingAttemptAsync(
        HttpClient client,
        string accessToken,
        SeededHotel hotel,
        DateOnly checkInDate,
        DateOnly checkOutDate)
    {
        using HttpRequestMessage request = new(
            HttpMethod.Post,
            $"/api/hotels/{hotel.HotelId}/front-desk/walk-in-bookings");
        request.Headers.Authorization = Bearer(accessToken);
        request.Content = JsonContent.Create(
            new
            {
                roomTypeId = hotel.RoomTypeId,
                roomCount = 1,
                physicalRoomIds = Array.Empty<Guid>(),
                checkInDate,
                checkOutDate,
                guestCount = 1,
                guestFullName = "Concurrent Walk In Guest",
                guestPhone = "0987654321",
                identityDocumentNumber = "CROSSCHANNEL",
                cashCollectedAmount = 200m
            },
            options: JsonOptions);

        using HttpResponseMessage response = await client.SendAsync(request);
        return response.StatusCode;
    }

    private static async Task<HttpStatusCode> SendCheckInAttemptAsync(
        HttpClient client,
        string accessToken,
        Guid hotelId,
        Guid bookingId,
        Guid physicalRoomId,
        string guestFullName)
    {
        using HttpRequestMessage request = new(
            HttpMethod.Post,
            $"/api/hotels/{hotelId}/front-desk/bookings/{bookingId}/check-in");
        request.Headers.Authorization = Bearer(accessToken);
        request.Content = JsonContent.Create(
            new
            {
                physicalRoomIds = new[] { physicalRoomId },
                guestFullName,
                identityDocumentNumber = "CONCURRENT"
            },
            options: JsonOptions);

        HttpResponseMessage response = await client.SendAsync(request);
        return response.StatusCode;
    }

    private async Task<TestAuthResponse> SeedUserAndLoginAsync(
        HttpClient client,
        UserRoleCode role,
        string emailPrefix,
        Guid? hotelId = null)
    {
        string suffix = Guid.NewGuid().ToString("N");
        string email = $"{emailPrefix}-{suffix}@example.com";
        string password = "IntegrationPassword123!";

        using IServiceScope scope = _factory.Services.CreateScope();
        HotelMarketplaceDbContext dbContext = scope.ServiceProvider.GetRequiredService<HotelMarketplaceDbContext>();
        HotelMarketplace.Application.Authentication.IPasswordHasher passwordHasher =
            scope.ServiceProvider.GetRequiredService<HotelMarketplace.Application.Authentication.IPasswordHasher>();

        Guid roleId = role switch
        {
            UserRoleCode.Customer => SeededRoleIds.Customer,
            UserRoleCode.PropertyOwner => SeededRoleIds.PropertyOwner,
            UserRoleCode.HotelManager => SeededRoleIds.HotelManager,
            UserRoleCode.Receptionist => SeededRoleIds.Receptionist,
            UserRoleCode.HousekeepingStaff => SeededRoleIds.HousekeepingStaff,
            UserRoleCode.MaintenanceStaff => SeededRoleIds.MaintenanceStaff,
            UserRoleCode.PlatformAdministrator => SeededRoleIds.PlatformAdministrator,
            _ => throw new InvalidOperationException("Unsupported role.")
        };

        UserAccount user = new(Guid.NewGuid(), email, passwordHasher.HashPassword(password), $"Test {role}", null);
        dbContext.UserAccounts.Add(user);
        dbContext.UserAccountRoles.Add(new UserAccountRole(Guid.NewGuid(), user.Id, roleId));

        if (hotelId.HasValue)
        {
            dbContext.HotelStaffAssignments.Add(new HotelStaffAssignment(Guid.NewGuid(), user.Id, hotelId.Value, roleId, user.Id));
        }

        await dbContext.SaveChangesAsync();

        TestAuthResponse authResponse = await PostJsonAsync<TestAuthResponse>(
            client,
            "/api/auth/login",
            new { email, password },
            HttpStatusCode.OK);

        authResponse.AccessToken.Should().NotBeNullOrWhiteSpace();
        return authResponse;
    }

    private async Task<SeededHotel> SeedBookableHotelAsync(int physicalRoomCount)
    {
        using IServiceScope scope = _factory.Services.CreateScope();
        HotelMarketplaceDbContext dbContext = scope.ServiceProvider.GetRequiredService<HotelMarketplaceDbContext>();

        UserAccount owner = CreateSeedUser("hotel-owner");
        HotelProperty hotel = CreateApprovedHotel(owner.Id, "Marketplace Harbor Suites");
        RoomType roomType = new(Guid.NewGuid(), hotel.Id, "Deluxe", 2, 1, 100m);
        List<PhysicalRoom> rooms = Enumerable.Range(1, physicalRoomCount)
            .Select(index => new PhysicalRoom(Guid.NewGuid(), hotel.Id, roomType.Id, $"10{index}"))
            .ToList();

        dbContext.UserAccounts.Add(owner);
        dbContext.HotelProperties.Add(hotel);
        dbContext.RoomTypes.Add(roomType);
        dbContext.PhysicalRooms.AddRange(rooms);
        await dbContext.SaveChangesAsync();

        return new SeededHotel(
            hotel.Id,
            roomType.Id,
            rooms.Select(room => room.Id).ToArray());
    }

    private async Task<Guid> SeedRefundAsync(Guid hotelId, Guid bookingId)
    {
        using IServiceScope scope = _factory.Services.CreateScope();
        HotelMarketplaceDbContext dbContext = scope.ServiceProvider.GetRequiredService<HotelMarketplaceDbContext>();

        RefundRecord refund = new(Guid.NewGuid(), hotelId, bookingId, 50m, "Smoke refund request");
        dbContext.RefundRecords.Add(refund);
        await dbContext.SaveChangesAsync();

        return refund.Id;
    }

    private static HotelProperty CreateApprovedHotel(Guid ownerUserAccountId, string name)
    {
        HotelProperty hotel = new(
            Guid.NewGuid(),
            ownerUserAccountId,
            name,
            "Ho Chi Minh City",
            "1 Integration Street",
            $"contact-{Guid.NewGuid():N}@example.com",
            "0900000000",
            "Integration test hotel");

        hotel.Approve();
        return hotel;
    }

    private static UserAccount CreateSeedUser(string prefix)
    {
        return new UserAccount(
            Guid.NewGuid(),
            $"{prefix}-{Guid.NewGuid():N}@example.com",
            "not-used-password-hash",
            "Seed User",
            null);
    }

    private static AuthenticationHeaderValue Bearer(string accessToken)
    {
        return new AuthenticationHeaderValue("Bearer", accessToken);
    }

    private static string TestPhoneNumber(string seed)
    {
        int hash = Math.Abs(seed.GetHashCode(StringComparison.Ordinal));
        return $"09{hash % 100_000_000:D8}";
    }

    private static async Task<TestAuthResponse> LoginAsync(HttpClient client, string email, string password)
    {
        return await PostJsonAsync<TestAuthResponse>(
            client,
            "/api/auth/login",
            new { email, password },
            HttpStatusCode.OK);
    }

    private static async Task<TResponse> PostJsonAsync<TResponse>(
        HttpClient client,
        string requestUri,
        object payload,
        HttpStatusCode expectedStatusCode,
        string? accessToken = null)
    {
        using HttpRequestMessage request = new(HttpMethod.Post, requestUri);

        if (!string.IsNullOrWhiteSpace(accessToken))
        {
            request.Headers.Authorization = Bearer(accessToken);
        }

        request.Content = JsonContent.Create(payload, options: JsonOptions);

        HttpResponseMessage response = await client.SendAsync(request);
        string responseBody = await response.Content.ReadAsStringAsync();
        response.StatusCode.Should().Be(expectedStatusCode, responseBody);

        TResponse? body = JsonSerializer.Deserialize<TResponse>(responseBody, JsonOptions);
        body.Should().NotBeNull();
        return body!;
    }

    private static async Task<TResponse> SendJsonAsync<TResponse>(
        HttpClient client,
        HttpMethod method,
        string requestUri,
        object payload,
        HttpStatusCode expectedStatusCode,
        string? accessToken = null)
    {
        using HttpRequestMessage request = new(method, requestUri);

        if (!string.IsNullOrWhiteSpace(accessToken))
        {
            request.Headers.Authorization = Bearer(accessToken);
        }

        request.Content = JsonContent.Create(payload, options: JsonOptions);

        HttpResponseMessage response = await client.SendAsync(request);
        string responseBody = await response.Content.ReadAsStringAsync();
        response.StatusCode.Should().Be(expectedStatusCode, responseBody);

        TResponse? body = JsonSerializer.Deserialize<TResponse>(responseBody, JsonOptions);
        body.Should().NotBeNull();
        return body!;
    }

    private static async Task<TResponse> GetJsonAsync<TResponse>(
        HttpClient client,
        string requestUri,
        HttpStatusCode expectedStatusCode,
        string? accessToken = null)
    {
        using HttpRequestMessage request = new(HttpMethod.Get, requestUri);

        if (!string.IsNullOrWhiteSpace(accessToken))
        {
            request.Headers.Authorization = Bearer(accessToken);
        }

        HttpResponseMessage response = await client.SendAsync(request);
        string responseBody = await response.Content.ReadAsStringAsync();
        response.StatusCode.Should().Be(expectedStatusCode, responseBody);

        TResponse? body = JsonSerializer.Deserialize<TResponse>(responseBody, JsonOptions);
        body.Should().NotBeNull();
        return body!;
    }

    private static async Task SendNoContentAsync(
        HttpClient client,
        HttpMethod method,
        string requestUri,
        HttpStatusCode expectedStatusCode,
        string? accessToken = null)
    {
        using HttpRequestMessage request = new(method, requestUri);

        if (!string.IsNullOrWhiteSpace(accessToken))
        {
            request.Headers.Authorization = Bearer(accessToken);
        }

        HttpResponseMessage response = await client.SendAsync(request);
        string responseBody = await response.Content.ReadAsStringAsync();
        response.StatusCode.Should().Be(expectedStatusCode, responseBody);
    }

    private sealed record SeededHotel(
        Guid HotelId,
        Guid RoomTypeId,
        IReadOnlyCollection<Guid> PhysicalRoomIds);

    private sealed record TestAuthResponse(
        Guid UserId,
        string Email,
        List<UserRoleCode> Roles,
        List<Guid> HotelIds,
        string AccessToken,
        DateTime ExpiresAtUtc);
}
