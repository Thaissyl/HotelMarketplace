using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;
using FluentAssertions;
using HotelMarketplace.Application.Bookings.Dtos;
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

        PaymentWebhookResultDto simulatedPayment = await PostJsonAsync<PaymentWebhookResultDto>(
            client,
            $"/api/bookings/{booking.Id}/simulate-payment-success",
            new { },
            HttpStatusCode.OK,
            customer.AccessToken);

        simulatedPayment.Status.Should().Be("processed");

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
                fullName = "Smoke Test Owner",
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
                name = $"Smoke Hotel {suffix}",
                city = "Ho Chi Minh City",
                addressLine = "99 Smoke Street",
                contactEmail = $"smoke-hotel-{suffix}@example.com",
                contactPhone = "0907654321",
                description = "Integration smoke hotel"
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
                name = $"Smoke Hotel Updated {suffix}",
                city = "Ho Chi Minh City",
                addressLine = "100 Smoke Street",
                contactEmail = $"smoke-hotel-updated-{suffix}@example.com",
                contactPhone = "0907654321",
                description = "Updated smoke hotel"
            },
            HttpStatusCode.OK,
            owner.AccessToken);
        updatedHotel.Name.Should().StartWith("Smoke Hotel Updated");

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
                guestPhone = "0912345678"
            },
            HttpStatusCode.Created,
            customer.AccessToken);

        PaymentWebhookResultDto simulatedPayment = await PostJsonAsync<PaymentWebhookResultDto>(
            client,
            $"/api/bookings/{booking.Id}/simulate-payment-success",
            new { },
            HttpStatusCode.OK,
            customer.AccessToken);
        simulatedPayment.Status.Should().Be("processed");

        await GetJsonAsync<JsonElement>(client, "/api/payments/payos/return", HttpStatusCode.OK);
        await GetJsonAsync<JsonElement>(client, "/api/payments/payos/cancel", HttpStatusCode.OK);

        await PostJsonAsync<JsonElement>(
            client,
            "/api/payments/payos/webhook",
            new
            {
                code = "00",
                desc = "success",
                success = true,
                data = new
                {
                    orderCode = 123456789L,
                    amount = 130,
                    description = "invalid signature smoke",
                    accountNumber = "000000",
                    reference = "INVALID",
                    transactionDateTime = DateTime.UtcNow.ToString("O"),
                    currency = "VND",
                    paymentLinkId = "INVALID",
                    code = "00",
                    desc = "success",
                    counterAccountBankId = (string?)null,
                    counterAccountBankName = (string?)null,
                    counterAccountName = (string?)null,
                    counterAccountNumber = (string?)null,
                    virtualAccountName = (string?)null,
                    virtualAccountNumber = (string?)null
                },
                signature = "invalid"
            },
            HttpStatusCode.BadRequest);

        TestAuthResponse receptionist = await SeedUserAndLoginAsync(client, UserRoleCode.Receptionist, "smoke-receptionist", hotel.Id);
        TestAuthResponse housekeeper = await SeedUserAndLoginAsync(client, UserRoleCode.HousekeepingStaff, "smoke-housekeeper", hotel.Id);
        TestAuthResponse maintenance = await SeedUserAndLoginAsync(client, UserRoleCode.MaintenanceStaff, "smoke-maintenance", hotel.Id);

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
                name = $"Reject Smoke Hotel {suffix}",
                city = "Da Nang",
                addressLine = "1 Reject Street",
                contactEmail = $"reject-smoke-{suffix}@example.com",
                contactPhone = "0901112222",
                description = "Hotel for rejection smoke"
            },
            HttpStatusCode.Created,
            owner.AccessToken);

        AdminHotelDto rejectedHotel = await PostJsonAsync<AdminHotelDto>(
            client,
            $"/api/platform-admin/hotels/{hotelToReject.Id}/reject",
            new { reason = "Smoke rejection" },
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
                guestPhone = "0900000000"
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
                guestPhone = "0911111111"
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
        HotelProperty hotel = CreateApprovedHotel(owner.Id, $"Bookable Hotel {Guid.NewGuid():N}");
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
