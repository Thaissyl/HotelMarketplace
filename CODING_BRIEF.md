# Hotel Marketplace Management System - Coding Brief

Source docs:
- `software-design-document.docx`
- `srs-final-mvp-semantic-repair.docx`

Generated for implementation preparation. Extracted text is under `_codex_doc_extract/`.

## Product Scope

Build a multi-tenant hotel marketplace and hotel operations system.

Main users:
- Guest
- Customer
- Property Owner
- Hotel Manager
- Receptionist
- Housekeeping Staff
- Maintenance Staff
- Platform Administrator

External actors:
- payOS Payment Gateway
- Notification Service or mock notification recorder
- System Scheduler

MVP scope:
- Hotel only, private rooms only.
- Guests can search and view approved public hotels.
- Customers can register, log in, book, pay online or pay at property, cancel, and view refund status.
- Property Owners and Hotel Managers manage hotel profile, room types, physical rooms, availability, and staff.
- Receptionists handle arrivals, room assignment, check-in, checkout, no-show, pay-at-property collection, and walk-in booking.
- Housekeeping and Maintenance manage room cleaning and maintenance workflows.
- Platform Administrator approves hotels and handles finance operations manually.

Out of scope:
- Shared beds, apartments, flights, tours, loyalty, chat, automated refund, automated bank payout, separate hotel cashier/accountant role.

## Target Stack

- Mobile client: Flutter
- Backend API: ASP.NET Core Web API, C#
- Architecture: Clean Architecture
- Database: Microsoft SQL Server
- Payment: payOS
- Notifications: mock or future provider

Suggested backend packages:
- `Presentation.Api`
- `Application`
- `Domain`
- `Infrastructure.Persistence`
- `Infrastructure.Payment`
- `Infrastructure.Notification`
- `Infrastructure.Scheduling`
- `SharedKernel`

## Core Domain Entities / Tables

- `UserAccounts`
- `UserRoles`
- `UserAccountRoles`
- `HotelStaffAssignments`
- `StaffInvitations`
- `HotelProperties`
- `HotelImages`
- `Amenities`
- `HotelAmenities`
- `CancellationPolicies`
- `RoomTypes`
- `PhysicalRooms`
- `RoomAvailabilities`
- `Bookings`
- `BookingRooms`
- `BookingRoomAssignments`
- `PaymentTransactions`
- `PaymentCollectionRecords`
- `RefundRecords`
- `Invoices`
- `CommissionRecords`
- `SettlementRecords`
- `SettlementItems`
- `NotificationRecords`
- `AuditRecords`
- `HousekeepingTasks`
- `MaintenanceRequests`
- `RoomStatusHistories`
- `GuestStayRecords`

Important constraints:
- Unique email and/or phone for accounts.
- Active staff assignment unique by `UserAccountId`, `HotelId`, `RoleId`.
- Physical room number unique within a hotel.
- Booking search index by hotel/date/status.
- Availability index by hotel/room type/date/status.
- Unique payOS gateway reference for idempotent callbacks.
- Audit index by target entity and timestamp.

## Important Business Rules

Authentication and authorization:
- Guest must register or log in before creating a booking.
- Users can have multiple roles.
- Hotel staff roles are hotel-scoped.
- Platform roles do not grant hotel tenant permissions unless explicitly assigned.
- Inactive or blocked accounts cannot log in.
- Staff can access only assigned hotels.
- Users can update only their own basic profile unless using an authorized admin function.

Marketplace and room availability:
- Only approved, active, public hotels appear in search/detail.
- Checkout date must be after check-in date.
- Blocked, inactive, occupied, dirty, cleaning, inspection-required, maintenance, and out-of-service rooms must not count as available for new assignment.
- Availability model is hybrid: booking reserves room type quantity/date; physical room assignment happens before or during check-in.

Booking:
- Instant booking after availability validation.
- Availability check and reservation must be atomic to prevent overbooking across customer and walk-in channels.
- MVP booking contains exactly one room type line and private room quantity.
- Booking amount = unit price per night x room quantity x night count.
- Pay at Property booking becomes `Confirmed` immediately after availability validation.
- Platform Collect booking stays `Pending Payment` until successful payment or timeout.
- Pending payment expires after 15 minutes by default.

Payment and finance:
- Online payment result updates `PaymentTransactions` and `Bookings` consistently.
- Duplicate payment notifications must not create duplicate successful payment or commission records.
- First atomic transition wins: successful payment confirmation or unpaid timeout.
- Commission default is 10%, allowed range is 0% to 30%.
- Platform Collect hotel payable considers paid amount, refund amount, and commission.
- Pay at Property creates commission receivable owed by hotel to platform.
- Refund processing and settlements are manual in MVP.

Operations:
- Check-in verifies booking, captures basic identity document fields, assigns physical room, creates guest stay record, updates room status/history.
- Checkout finalizes stay, records pay-at-property collection if needed, creates invoice/folio, releases room into housekeeping path.
- Checkout auto-creates housekeeping task and marks room dirty or cleaning required.
- Maintenance release returns room to cleaning/available path according to room status rule.
- Protected staff, finance, booking, room, housekeeping, and maintenance actions should create audit records.

## Main Use Cases

- UC-001 Search Hotels
- UC-002 View Hotel Detail
- UC-003 Register Account
- UC-004 Login
- UC-005 Create Booking
- UC-006 Pay Online
- UC-007 Cancel Booking
- UC-008 View My Bookings
- UC-009 Register Hotel Property
- UC-010 Manage Hotel Profile
- UC-011 Manage Room Type
- UC-012 Manage Physical Room
- UC-013 Manage Room Availability
- UC-014 View Hotel Bookings
- UC-015 Check In Customer
- UC-016 Check Out Customer
- UC-017 Mark No-show
- UC-018 Approve Hotel Property
- UC-019 Manage Commission Rate
- UC-020 Reconcile Payment
- UC-021 Process Refund Status
- UC-022 Mark Settlement
- UC-023 View Platform Dashboard
- UC-024 Expire Unpaid Booking
- UC-025 Manage Own Profile
- UC-026 Manage Hotel Staff Accounts
- UC-027 Assign Staff Roles and Permissions
- UC-028 View Arrival and Departure List
- UC-029 Assign Physical Room
- UC-030 Record Pay-at-Property Payment
- UC-031 Create Walk-in Booking
- UC-032 View Housekeeping Tasks
- UC-033 Update Room Cleaning Status
- UC-034 Report Room Issue
- UC-035 View Maintenance Requests
- UC-036 Update Maintenance Request
- UC-037 Release Room from Maintenance

## Recommended Implementation Order

1. Create solution structure and shared primitives.
2. Implement authentication, roles, hotel-scoped authorization, and seed roles/admin.
3. Implement core database entities and EF Core mappings/migrations.
4. Implement marketplace read flows: search hotels, hotel detail, availability summary.
5. Implement customer booking and atomic availability reservation.
6. Implement payOS payment instruction/callback and unpaid booking expiration job.
7. Implement owner/manager hotel setup and room inventory.
8. Implement staff management and scoped permissions.
9. Implement front desk check-in/checkout/no-show/walk-in flows.
10. Implement housekeeping and maintenance workflows.
11. Implement platform approval, commission, reconciliation, refund, settlement, dashboard.
12. Add audit, notification records, test data, and integration tests for critical state transitions.

## First Backend Skeleton Candidates

Domain enums:
- `RoleCode`
- `RoleScope`
- `AccountStatus`
- `HotelApprovalStatus`
- `HotelPublicationStatus`
- `RoomTypeStatus`
- `PhysicalRoomStatus`
- `AvailabilityStatus`
- `BookingStatus`
- `PaymentMode`
- `BookingSource`
- `PaymentStatus`
- `ReconciliationStatus`
- `RefundStatus`
- `InvoiceStatus`
- `CommissionStatus`
- `SettlementStatus`
- `HousekeepingTaskStatus`
- `MaintenanceRequestStatus`
- `NotificationStatus`

Critical application services:
- `AuthService`
- `HotelAuthorizationService`
- `MarketplaceService`
- `AvailabilityService`
- `BookingService`
- `PaymentService`
- `PayOsWebhookService`
- `FrontDeskService`
- `HousekeepingService`
- `MaintenanceService`
- `FinanceService`
- `NotificationDispatcher`
- `AuditService`

Critical test targets:
- Customer cannot book unavailable room type.
- Atomic booking prevents overbooking.
- PayOS duplicate callback is idempotent.
- Payment success vs expiration race uses first transition wins.
- Staff cannot access unassigned hotel.
- Platform admin cannot implicitly access tenant hotel operations.
- Check-in cannot assign overlapping physical room.
- Checkout creates housekeeping task and room status history.
