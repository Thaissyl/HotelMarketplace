using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;
using FluentAssertions;
using HotelMarketplace.Application.Bookings.Dtos;
using HotelMarketplace.Application.FrontDesk.Dtos;
using HotelMarketplace.Application.Payments.Dtos;
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
                phoneNumber = $"10{suffix[..8]}",
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
