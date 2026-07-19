---
type: code-review
date: 2026-07-18
source-commit: 0681fb9
status: verified
---

# SRS/SDD-to-Codebase Deviation Report

## 1. Purpose and scope

This report compares the implementation at commit 0681fb9 with:

- [Software Requirement Specification](./software-requirement-document.docx)
- [Software Design Document](./software-design-document.docx)

The review covers the ASP.NET Core backend, Flutter mobile application, database-facing
implementation, authorization boundaries, payment and finance flows, operational room
workflows, and available automated tests.

The SDD states that its class and method names are conceptual because the codebase was
not inspected when it was written. Consequently, this review treats different names or
file layouts as acceptable when the required behavior is present. A deviation is reported
only when behavior, data, authorization, lifecycle, UI coverage, or a required quality
attribute differs materially from the SRS/SDD.

### Finding terminology

| Term | Meaning |
|---|---|
| Confirmed | The behavior is directly reachable in the reviewed code. |
| Missing | No application/API operation implementing the documented capability was found. |
| Partial | Part of the documented behavior exists, but required branches or data are absent. |
| Inferred | The code model permits the issue, but ordinary current UI/API setup may limit reachability. |
| Test limitation | The available tests do not establish the claimed requirement. |

Severity reflects business impact, security exposure, financial integrity, and the
likelihood of inconsistent production data.

## 2. Executive summary

The codebase has a credible Clean Architecture skeleton and implements many happy paths,
but it is not behaviorally aligned with the SRS/SDD in several high-risk areas.

| Severity | Count | Main themes |
|---|---:|---|
| Critical | 3 | Payment bypass, tenant isolation, cross-channel overbooking |
| High | 17 | Finance integrity, missing lifecycle operations, authorization, mobile reachability |
| Medium | 10 | Partial use cases, incomplete data, task ownership, testability |
| Low | 3 | Dependency/tooling/infrastructure drift |

The three release-blocking issues are:

1. A customer can mark their own booking paid through an unguarded simulation endpoint.
2. Platform Administrator is granted implicit access to every hotel's operational data.
3. Online reservations and walk-ins use different inventory models and locks, allowing
   room-type inventory to be oversold.

Build success or a successful demo does not negate these deviations. Most findings concern
business invariants and alternate flows that the existing automated suite does not cover.

## 3. Areas that substantially conform

The review found the following meaningful alignment:

- The backend is separated into the expected domain, application, infrastructure, and
  presentation projects, with dependencies mostly pointing inward.
- The documented core entities and tables are broadly represented, including bookings,
  hotels, room types, physical rooms, staff assignments, payment transactions,
  commissions, settlements, refunds, audit records, housekeeping tasks, and maintenance
  requests.
- Database configuration includes important uniqueness and lookup constraints for user
  email/phone, staff assignment, hotel room number, booking status/date queries, payOS
  references, and audit lookup.
- Public browsing filters hotels to approved and published records.
- Customer booking uses a serializable transaction and SQL application lock for competing
  online customers, calculates room-type quantity, and creates the documented short-lived
  pending-payment reservation.
- A real payOS adapter, HMAC verification, and expired-booking scheduler exist.
- Check-in, checkout, walk-in, housekeeping, maintenance, hotel approval, reconciliation,
  and settlement happy paths have identifiable backend implementations.
- The mobile application exposes the principal customer, owner/operations, and platform
  administration areas.

These conformance points should be retained while the deviations below are corrected.

## 4. Critical deviations

### CRIT-01 — Customer-controlled payment-success simulation

**Status:** Confirmed
**Document baseline:** UC-006, BR-PAY-001, BR-PAY-005, SDD section 3.6.

**Evidence**

- The customer-authorized controller exposes
  [POST simulate-payment-success](../backend/src/Presentation.Api/Controllers/BookingsController.cs#L78-L91).
- The application service only requires an authenticated user in
  [PaymentService.cs](../backend/src/Application/Payments/PaymentService.cs#L115-L139).
- Persistence marks a simulated transaction paid, confirms the booking, and creates
  commission without payOS proof in
  [EfPaymentRepository.cs](../backend/src/Infrastructure.Persistence/Payments/EfPaymentRepository.cs#L307-L397).
- The mobile payment button directly calls this endpoint through
  [booking_api.dart](../mobile/lib/features/bookings/data/booking_api.dart#L30-L35) and
  [pending_payment_screen.dart](../mobile/lib/features/bookings/presentation/pending_payment_screen.dart#L117-L140).

**Deviation and impact:** The documented flow requires verified provider payment before
confirmation. A customer can instead create a paid transaction and confirmed booking
without transferring money, which can also generate an invalid commission record.

**Required correction:** Remove the endpoint from production, or compile and authorize it
behind an explicit non-production-only guard inaccessible to customer tokens. The mobile
flow must use the payment-link endpoint and provider return/callback result.

### CRIT-02 — Platform Administrator bypasses hotel tenant isolation

**Status:** Confirmed
**Document baseline:** BR-AUTH-002 and the hotel-scoped actor boundaries for UC-015 through
UC-037.

**Evidence**

- [HotelAccessAuthorizer.cs](../backend/src/Application/Security/HotelAccessAuthorizer.cs#L14-L26)
  returns true unconditionally for Platform Administrator.
- [HotelScopedAuthorizationHandler.cs](../backend/src/Presentation.Api/Authorization/HotelScopedAuthorizationHandler.cs#L20-L29)
  delegates hotel access to that rule.
- Operational controllers explicitly admit that role, for example
  [FrontDeskController.cs](../backend/src/Presentation.Api/Controllers/FrontDeskController.cs#L13-L20).

**Deviation and impact:** The SRS says a platform role must not imply hotel-tenant
permission unless explicitly assigned. The implementation permits a Platform Administrator
to read guest data and mutate front-desk, housekeeping, and maintenance state for any
hotel ID.

**Required correction:** Separate platform governance permissions from hotel operational
permissions. Require a hotel assignment or a narrowly scoped, audited support-elevation
mechanism for every tenant operation.

### CRIT-03 — Online and walk-in inventory can overbook the same room type

**Status:** Confirmed
**Document baseline:** UC-031, BR-BOOK-013, SDD section 3.31.

**Evidence**

- Online booking locks and subtracts overlapping booking-room quantities by hotel,
  room type, and date in
  [EfBookingRepository.cs](../backend/src/Infrastructure.Persistence/Bookings/EfBookingRepository.cs#L106-L132).
- Walk-in creation locks selected physical rooms and checks only physical-room assignment
  overlap in
  [EfFrontDeskRepository.cs](../backend/src/Infrastructure.Persistence/FrontDesk/EfFrontDeskRepository.cs#L444-L501).
- The walk-in booking and assignment are created separately from the room-type inventory
  check in
  [EfFrontDeskRepository.cs](../backend/src/Infrastructure.Persistence/FrontDesk/EfFrontDeskRepository.cs#L533-L594).

**Deviation and impact:** A confirmed or pending online reservation normally has no
physical-room assignment. A receptionist can therefore select a physical room whose
room-type capacity has already been reserved online. Total committed quantity can exceed
inventory. A future-dated walk-in is also immediately marked occupied/checked-in.

**Required correction:** Use one date-range inventory invariant and one compatible lock
strategy for marketplace, walk-in, amendments, cancellation, and assignment. Do not
change current physical occupancy for a future stay.

## 5. High-severity deviations

### HIGH-01 — Marketplace Pay at Property is unavailable

**Status:** Missing
**Document baseline:** UC-005 alternate flow AT-06B and BR-BOOK-005.

The booking request has no payment-mode field in
[CreateBookingRequest.cs](../backend/src/Application/Bookings/Requests/CreateBookingRequest.cs#L3-L11),
and persistence hard-codes PlatformCollect in
[EfBookingRepository.cs](../backend/src/Infrastructure.Persistence/Bookings/EfBookingRepository.cs#L140-L160).
Customers therefore cannot select the documented Pay-at-Property option.

### HIGH-02 — Pay-at-Property commission and settlement are structurally unreachable

**Status:** Confirmed
**Document baseline:** UC-022, UC-030, UC-031, and BR-FIN-003.

Walk-in creation records a Pay-at-Property booking and optional collection but creates no
commission in
[EfFrontDeskRepository.cs](../backend/src/Infrastructure.Persistence/FrontDesk/EfFrontDeskRepository.cs#L509-L575).
Production commission creation is confined to successful platform-payment processing in
[EfPaymentRepository.cs](../backend/src/Infrastructure.Persistence/Payments/EfPaymentRepository.cs#L280-L301).
The Pay-at-Property settlement query requires an existing commission through an inner join
in
[EfPlatformAdminRepository.cs](../backend/src/Infrastructure.Persistence/PlatformAdmin/EfPlatformAdminRepository.cs#L847-L869).
Normal Pay-at-Property bookings therefore cannot enter the documented commission
receivable/settlement flow.

### HIGH-03 — Settlement permits unreconciled payments and ignores refunds

**Status:** Confirmed
**Document baseline:** UC-022, BR-FIN-002, and BR-FIN-007.

[EfPlatformAdminRepository.cs](../backend/src/Infrastructure.Persistence/PlatformAdmin/EfPlatformAdminRepository.cs#L818-L844)
excludes only the Exception reconciliation state, so Unreconciled transactions remain
eligible. It calculates payment minus commission without joining or subtracting approved
or processed refunds. This can settle money before reconciliation or overpay a hotel after
a refund.

### HIGH-04 — Retry after a failed provider callback reuses an unusable transaction

**Status:** Confirmed
**Document baseline:** UC-006 alternate flow AT-08A and BR-PAY-001/005.

The payment-link path returns the existing transaction/link in
[EfPaymentRepository.cs](../backend/src/Infrastructure.Persistence/Payments/EfPaymentRepository.cs#L120-L145).
After a failed/cancelled callback, a later success attempts to mark that failed transaction
paid in
[EfPaymentRepository.cs](../backend/src/Infrastructure.Persistence/Payments/EfPaymentRepository.cs#L263-L280),
while
[PaymentTransaction.cs](../backend/src/Domain/Entities/PaymentTransaction.cs#L77-L87)
does not allow that transition. A customer can pay on a reused link yet leave the booking
unconfirmed.

### HIGH-05 — Late and duplicate provider events are not durably audited

**Status:** Confirmed
**Document baseline:** UC-006 AT-08C, UC-024, and BR-PAY-005.

[EfPaymentRepository.cs](../backend/src/Infrastructure.Persistence/Payments/EfPaymentRepository.cs#L249-L277)
rejects a late success and short-circuits a duplicate, but creates no provider-event or
audit record. Finance operators lack the documented trace needed to reconcile money
received after expiration or repeated callbacks.

### HIGH-06 — Cancel Booking and Mark No-show are absent

**Status:** Missing
**Document baseline:** UC-007, UC-017, and SDD sections 3.7/3.17.

[IBookingService.cs](../backend/src/Application/Bookings/IBookingService.cs#L7-L14)
offers only create and query operations, while
[IFrontDeskService.cs](../backend/src/Application/FrontDesk/IFrontDeskService.cs#L9-L38)
has no no-show operation. The
[Booking entity](../backend/src/Domain/Entities/Booking.cs#L103-L151)
also has no cancel/no-show transition. Capacity release, refund initiation, and no-show
financial trace are consequently unavailable.

### HIGH-07 — Hotel availability management is absent and operational filtering is unsafe

**Status:** Missing/partial
**Document baseline:** UC-013 and BR-ROOM-002.

[IHotelManagementService.cs](../backend/src/Application/HotelManagement/IHotelManagementService.cs#L7-L40)
has no availability calendar or date-block management operation. Marketplace availability
also treats only Maintenance, OutOfService, Blocked, and Inactive as unavailable in
[EfMarketplaceBrowsingRepository.cs](../backend/src/Infrastructure.Persistence/Marketplace/EfMarketplaceBrowsingRepository.cs#L19-L24).
The room enum includes Assigned, Occupied, Dirty, Cleaning, and InspectionRequired in
[RoomOperationalStatus.cs](../backend/src/Domain/Enums/RoomOperationalStatus.cs#L5-L14).
For current-day search, rooms in those states can be counted as saleable. Future-date
treatment needs an explicit product rule, but the current-day mismatch is definite.

### HIGH-08 — Refund processing cannot start through production behavior

**Status:** Missing
**Document baseline:** UC-021 and the cancellation/refund lifecycle.

Production code only lists and updates existing refunds in
[EfPlatformAdminRepository.cs](../backend/src/Infrastructure.Persistence/PlatformAdmin/EfPlatformAdminRepository.cs#L654-L760).
No production path creates a RefundRecord; the reviewed search found construction only in
the integration-test fixture at
[ApiIntegrationTests.cs](../backend/tests/Api.IntegrationTests/ApiIntegrationTests.cs#L1062).
The administrator can therefore process seeded/test refunds, but an actual customer event
cannot initiate the workflow.

### HIGH-09 — Documented Hotel Manager management scope is not implemented

**Status:** Confirmed authorization mismatch
**Document baseline:** UC-010 through UC-013, UC-026/027, and SDD decision DEC-004.

[OwnerHotelsController.cs](../backend/src/Presentation.Api/Controllers/OwnerHotelsController.cs#L12-L14)
restricts hotel profile, inventory, and staff management to HotelOwner. The service also
checks owner-level access in
[HotelManagementService.cs](../backend/src/Application/HotelManagement/HotelManagementService.cs#L399-L418).
The SRS/SDD assigns several of these capabilities to Hotel Manager, so a documented actor
cannot perform them.

### HIGH-10 — Role claims and hotel claims lose their assignment relationship

**Status:** Inferred; ordinary current staff creation limits reachability
**Document baseline:** BR-AUTH-002 and BR-STAFF-005/006.

Authentication loads roles and hotel IDs independently in
[EfAuthUserRepository.cs](../backend/src/Infrastructure.Persistence/Authentication/EfAuthUserRepository.cs#L62-L97),
then emits separate claim sets in
[JwtTokenGenerator.cs](../backend/src/Infrastructure.Persistence/Security/JwtTokenGenerator.cs#L26-L36).
The domain assignment actually stores the precise user/hotel/role tuple in
[HotelStaffAssignment.cs](../backend/src/Domain/Entities/HotelStaffAssignment.cs#L11-L30).
If a user has different roles at different hotels, authorization can combine a privileged
role from hotel A with the hotel-ID claim for hotel B. Current create-staff behavior creates
a new user/role together, so this is a confirmed scope-model flaw with a conditional
exploit path, not evidence of an already-created account.

### HIGH-11 — Checkout violates payment and invoice invariants

**Status:** Confirmed
**Document baseline:** UC-016, UC-030, BR-PAY-006, and BR-FIN-002/006.

[EfFrontDeskRepository.cs](../backend/src/Infrastructure.Persistence/FrontDesk/EfFrontDeskRepository.cs#L339-L357)
derives invoice paid amount from checkout cash rather than total prior online payment.
It can also record hotel cash for PlatformCollect and does not reject collection above the
remaining balance before persisting at
[EfFrontDeskRepository.cs](../backend/src/Infrastructure.Persistence/FrontDesk/EfFrontDeskRepository.cs#L418-L424).
The resulting invoice and finance ledger can disagree with actual payment mode and amount.

### HIGH-12 — Audit and notification coverage is materially incomplete

**Status:** Confirmed
**Document baseline:** BR-AUDIT-001, BR-NOTI-001, UC-024, and SDD transaction notes.

Production AuditRecord creation is concentrated in platform-administration persistence.
Booking/payment, check-in/out, walk-in, room setup, housekeeping, maintenance, and
expiration transitions save without the documented audit entry; examples include
[payment persistence](../backend/src/Infrastructure.Persistence/Payments/EfPaymentRepository.cs#L280-L301),
[check-in persistence](../backend/src/Infrastructure.Persistence/FrontDesk/EfFrontDeskRepository.cs#L280-L292),
and
[housekeeping persistence](../backend/src/Infrastructure.Persistence/Housekeeping/EfHousekeepingRepository.cs#L137-L151).
The notification infrastructure registers a no-op implementation in
[DependencyInjection.cs](../backend/src/Infrastructure.Notification/DependencyInjection.cs#L8-L14),
and no normal production path creates the expected notification records.

### HIGH-13 — Housekeeping and maintenance skip documented room-release states

**Status:** Confirmed
**Document baseline:** UC-033, UC-036/037, BR-HK-002/003, BR-MAINT-002, and BR-ROOM-006.

Housekeeping only accepts InProgress/Completed and completion always makes the room
available in
[HousekeepingValidators.cs](../backend/src/Application/Housekeeping/Validation/HousekeepingValidators.cs#L17-L23)
and
[EfHousekeepingRepository.cs](../backend/src/Infrastructure.Persistence/Housekeeping/EfHousekeepingRepository.cs#L121-L130).
Maintenance resolution likewise calls a method that hard-codes Available in
[EfMaintenanceRepository.cs](../backend/src/Infrastructure.Persistence/Maintenance/EfMaintenanceRepository.cs#L203-L218)
and
[PhysicalRoom.cs](../backend/src/Domain/Entities/PhysicalRoom.cs#L119-L127).
The documented inspection-required, dirty-after-maintenance, follow-up cleaning, and final
release branches cannot be represented.

### HIGH-14 — Owner room edits can bypass operational lifecycle safeguards

**Status:** Confirmed
**Document baseline:** BR-ROOM-006, BR-HK-002, and BR-MAINT-002.

The owner endpoint accepts direct status edits in
[OwnerHotelsController.cs](../backend/src/Presentation.Api/Controllers/OwnerHotelsController.cs#L205-L220).
[EfHotelManagementRepository.cs](../backend/src/Infrastructure.Persistence/HotelManagement/EfHotelManagementRepository.cs#L289-L368)
persists them through a setup-oriented state change without operational history or audit.
An owner can therefore move a dirty, occupied, or maintenance room directly to Available
while active bookings/tasks still say otherwise.

### HIGH-15 — Check-in does not enforce stay date or documented identity policy

**Status:** Confirmed
**Document baseline:** UC-015, BR-STAY-005, and SDD section 3.15.

[FrontDeskValidators.cs](../backend/src/Application/FrontDesk/Validation/FrontDeskValidators.cs#L8-L19)
does not validate arrival date and permits a missing identity number. Persistence proceeds
to checked-in/occupied state in
[EfFrontDeskRepository.cs](../backend/src/Infrastructure.Persistence/FrontDesk/EfFrontDeskRepository.cs#L193-L208).
Bookings can be checked in days early, and a hotel cannot enforce the documented identity
type/number requirement.

### HIGH-16 — Mobile blocks guest marketplace browsing and strands new owners

**Status:** Confirmed
**Document baseline:** public marketplace access, UC-009, SCR-015.

Marketplace/detail routes are classified as customer-only and unauthenticated users are
redirected to login in
[app_router.dart](../mobile/lib/app/router/app_router.dart#L44-L49) and
[app_router.dart](../mobile/lib/app/router/app_router.dart#L73-L85),
although the backend public controller is anonymous.

Owner registration is offered in
[register_screen.dart](../mobile/lib/features/auth/presentation/register_screen.dart#L121-L133),
but a new owner has no hotel and is routed to an empty operations state in
[operations_dashboard_screen.dart](../mobile/lib/features/operations/presentation/operations_dashboard_screen.dart#L26-L30).
The mobile operations API can update an existing hotel but cannot call the backend hotel
registration endpoint. Public browsing and owner onboarding therefore diverge from the
documented entry flows.

### HIGH-17 — Android production builds allow cleartext transport

**Status:** Confirmed
**Document baseline:** NFR-SEC-006.

[AndroidManifest.xml](../mobile/android/app/src/main/AndroidManifest.xml#L4-L8)
sets usesCleartextTraffic to true on the main application manifest, and
[app_environment.dart](../mobile/lib/core/config/app_environment.dart#L26-L55)
does not enforce HTTPS for production configuration. Credentials, guest data, and hotel
operations can be exposed if a production endpoint is configured with HTTP.

## 6. Medium-severity deviations

### MED-01 — UC-029 and UC-030 exist only as checkout/check-in side effects

**Status:** Partial
**Document baseline:** UC-029, UC-030, BR-PAY-006/007.

[IFrontDeskService.cs](../backend/src/Application/FrontDesk/IFrontDeskService.cs#L23-L38)
has no independent pre-assign/change-room or record-payment operation.
[PaymentCollectionRecord.cs](../backend/src/Domain/Entities/PaymentCollectionRecord.cs#L12-L37)
lacks method, reference, idempotency key, and a meaningful lifecycle. The happy path is
embedded in check-in/checkout/walk-in, but the documented independent operations and
alternate flows are unavailable.

### MED-02 — Staff management supports only a narrow create/list flow

**Status:** Partial
**Document baseline:** UC-026 and UC-027.

[IHotelManagementService.cs](../backend/src/Application/HotelManagement/IHotelManagementService.cs#L19-L23)
does not expose invite, update, deactivate, reassignment, or attach-existing-user
operations. Persistence creates a new user and assignment together in
[EfHotelManagementRepository.cs](../backend/src/Infrastructure.Persistence/HotelManagement/EfHotelManagementRepository.cs#L114-L136).
The documented ongoing staff lifecycle and multi-role cases are not supported.

### MED-03 — Profile management excludes hotel operations roles

**Status:** Confirmed authorization mismatch
**Document baseline:** UC-025.

[CustomerAccountController.cs](../backend/src/Presentation.Api/Controllers/CustomerAccountController.cs#L11-L14)
allows only Customer and Platform Administrator. The mobile client also targets only
customer account routes in
[customer_account_api.dart](../mobile/lib/features/customer/data/customer_account_api.dart#L9-L29).
Owners, managers, receptionists, housekeepers, and maintenance staff cannot manage their
own documented profile through this feature.

### MED-04 — Same-hotel staff can take over another assignee's task

**Status:** Confirmed
**Document baseline:** UC-032/033/035/036 and BR-STAFF-005/006.

[HousekeepingService.cs](../backend/src/Application/Housekeeping/HousekeepingService.cs#L68-L92)
checks hotel access but not current assignee, while
[HousekeepingTask.cs](../backend/src/Domain/Entities/HousekeepingTask.cs#L53-L63)
can overwrite the assignee when starting. Maintenance updates have the same scope issue in
[MaintenanceService.cs](../backend/src/Application/Maintenance/MaintenanceService.cs#L158-L182).

### MED-05 — Finance commands omit required reconciliation and settlement facts

**Status:** Partial
**Document baseline:** UC-020, UC-022, and BR-ADMIN-003.

[UpdatePaymentReconciliationRequest.cs](../backend/src/Application/PlatformAdmin/Requests/UpdatePaymentReconciliationRequest.cs#L5-L6)
cannot carry an exception note.
[CreateSettlementRequest.cs](../backend/src/Application/PlatformAdmin/Requests/CreateSettlementRequest.cs#L5-L10)
does not capture settlement date, actual amount, or payment/reference details. Operators
cannot persist the evidence required for exception handling and bank reconciliation.

### MED-06 — Booking guest count is not preserved

**Status:** Confirmed data loss
**Document baseline:** booking guest/occupancy details in UC-005 and UC-014.

The booking read model in
[EfBookingRepository.cs](../backend/src/Infrastructure.Persistence/Bookings/EfBookingRepository.cs#L217-L233)
hard-codes guest count to one instead of returning the customer's requested occupancy.
Operational staff can receive incorrect arrival and capacity information.

### MED-07 — Hotel and room detail models omit documented information

**Status:** Partial
**Document baseline:** hotel-detail and room-management requirements.

The implemented physical-room model does not preserve documented floor/notes fields, and
the marketplace hotel-detail response does not expose the complete image, amenity, and
cancellation-policy information expected by the SRS screens. This reduces both operational
room context and the customer's information before booking.

### MED-08 — Several mobile screen equivalents are missing or incomplete

**Status:** Missing/partial
**Document baseline:** SCR-012, SCR-013, SCR-019, SCR-022, SCR-038, and SCR-039.

- SCR-012 has only a success dialog after simulation, not a provider return/cancel/result
  flow in
  [pending_payment_screen.dart](../mobile/lib/features/bookings/presentation/pending_payment_screen.dart#L141-L169).
- SCR-013 customer refund status is absent from customer booking APIs.
- SCR-019 availability calendar/block management is absent from
  [operations_api.dart](../mobile/lib/features/operations/data/operations_api.dart#L1-L354).
- SCR-022 is not wholly absent: the embedded
  [front_desk_tab.dart](../mobile/lib/features/operations/presentation/front_desk_tab.dart#L23-L113)
  contains arrivals, checked-in, departures, history, and walk-in panels. It is partial
  because no-show candidates and room-status summary are missing.
- SCR-038/039 commission management and payment reconciliation are absent from
  [platform_admin_api.dart](../mobile/lib/features/platform_admin/data/platform_admin_api.dart#L57-L161),
  despite matching backend endpoints.

Combining documented screens into tabs or sheets is not itself a deviation; the missing
behavior within those equivalents is.

### MED-09 — Saved hotels and notifications are device-local substitutes

**Status:** Partial
**Document baseline:** cross-session saved-hotel and notification behavior.

[customer_state.dart](../mobile/lib/features/customer/application/customer_state.dart)
stores favorites and notification-like state locally rather than using durable,
server-backed user records. Data does not reliably follow the user across devices and is
not produced by backend business events.

### MED-10 — Automated tests do not protect the principal business invariants

**Status:** Test limitation

The Domain and Application unit-test projects contain test dependencies but no authored
test cases. The integration suite contains eight API tests, but does not cover the payment
simulation exposure, platform-admin tenant bypass, cross-channel inventory, cancellation,
no-show, refund creation, lifecycle bypasses, or production mobile routes. Flutter has one
shell/widget test in
[widget_test.dart](../mobile/test/widget_test.dart#L12-L41).

## 7. Low-severity deviations and project drift

### LOW-01 — Scheduling has an unnecessary persistence dependency

Infrastructure.Scheduling references Infrastructure.Persistence even though its observed
implementation needs only application abstractions. This weakens the intended project
dependency boundaries without currently changing business behavior.

### LOW-02 — Local infrastructure documentation and compose layout have drifted

The compose setup refers to an SQL initialization location not present in the reviewed
tree, and parts of the infrastructure README no longer match the actual startup layout.
This is operational/documentation drift rather than an SRS functional failure.

### LOW-03 — SDK pin does not match the project target or current validation host

[global.json](../global.json#L1-L5) requests .NET SDK 10.0.103 while
[Directory.Build.props](../Directory.Build.props#L1-L9) targets .NET 8. On the review host,
the normal dotnet command could not honor the pin because only SDK 8.0.422 was installed.
Explicit .NET 8 MSBuild compilation succeeded, but the repository's default developer
entry point is not reproducible on that host.

## 8. Use-case coverage summary

This table is a triage view, not a replacement for the detailed findings.

| Use case(s) | Assessment | Main deviation |
|---|---|---|
| UC-001 to UC-004 | Broadly present | Role/hotel claim association and profile scope remain unsafe/incomplete. |
| UC-005 | Partial | Pay-at-Property cannot be selected; guest details are incomplete. |
| UC-006 | Unsafe | Customer simulation bypasses provider payment; retry/event handling is incomplete. |
| UC-007 | Missing | No cancellation operation or domain transition. |
| UC-008 | Broadly present | Customer booking list/detail exists. |
| UC-009 | Backend present, mobile broken | New owner cannot register a hotel from the app. |
| UC-010 to UC-012 | Partial | Owner path exists; documented Hotel Manager permissions and detail fields differ. |
| UC-013 | Missing | No availability calendar/date blocking management. |
| UC-014 to UC-016 | Partial | Operational views exist; check-in and checkout invariants are incomplete. |
| UC-017 | Missing | No no-show operation or financial trace. |
| UC-018/019 | Broadly present | Approval and platform finance summary have identifiable paths. |
| UC-020 | Partial | Reconciliation exists, but exception data and eligibility rules are incomplete. |
| UC-021 | End-to-end broken | Refund records cannot be created by production behavior. |
| UC-022 | Unsafe/partial | Settlement eligibility, refunds, and Pay-at-Property commission are wrong. |
| UC-023/024 | Partial | Audit visibility exists mainly for admin changes; protected event coverage is incomplete. |
| UC-025 | Partial | Only Customer and Platform Administrator can use the profile API. |
| UC-026/027 | Partial | Create/list only; manager and staff lifecycle behavior are incomplete. |
| UC-028 | Broadly present | Operational room list has an identifiable path. |
| UC-029/030 | Partial | Behavior is embedded in check-in/out and lacks independent lifecycle/data. |
| UC-031 | Unsafe | Walk-in can conflict with online room-type inventory. |
| UC-032 to UC-035 | Partial | Task flows exist; inspection, severity, and assignee controls differ. |
| UC-036/037 | Partial | Resolve/release lifecycle collapses directly to Available. |

## 9. Mobile screen coverage summary

| Screen | Assessment | Evidence/notes |
|---|---|---|
| SCR-012 Payment Result | Partial | Simulation success dialog; no payOS return/cancel/result route. |
| SCR-013 Customer Refund Status | Missing | No customer refund API or route. |
| SCR-015 Hotel Registration | Missing in mobile | Backend endpoint exists, but new owner has no route/client action to call it. |
| SCR-019 Availability Calendar | Missing | No availability management API/UI in operations client. |
| SCR-022 Front Desk Dashboard | Partial | Core panels exist; no no-show candidates or room-status summary. |
| SCR-038 Commission Management | Missing in mobile | Backend capability is not exposed by the admin client. |
| SCR-039 Payment Reconciliation | Missing in mobile | Backend capability is not exposed by the admin client. |

Other SRS screens are often consolidated into tabs, dialogs, or bottom sheets. They should
be accepted as equivalent where all required behavior is present; visual one-to-one screen
matching was not used as a compliance criterion.

## 10. Verification performed and limitations

The review combined static tracing from controller to application/domain/persistence,
authorization checks, mobile route/API tracing, data-model inspection, and available build
or test commands.

- The repository was reviewed at commit 0681fb9.
- Normal dotnet invocation was blocked by the unavailable 10.0.103 SDK requested by
  global.json.
- Explicit .NET 8 MSBuild compiled the Presentation.Api and test projects with zero
  warnings and zero errors.
- No tests were discovered in the Domain or Application unit-test assemblies.
- The eight integration tests require SQL Server Testcontainers. In this review run they
  failed during fixture construction because Docker was not running; no business
  assertion was reached. The existing QA report records a previous 8/8 pass with Docker,
  but that result was not independently reproduced in this run.
- Flutter dependency resolution and static analysis completed without issues.
- Flutter executed one passing shell/widget test, which does not validate feature or
  business behavior.

Accordingly, compilation and static analysis establish basic code health, not SRS/SDD
conformance. Dynamic exploitation of the critical paths should be added as regression
tests after fixes are designed.

## 11. Recommended remediation order

### P0 — Release blockers

1. Remove or non-production-guard payment simulation and implement the real mobile payOS
   handoff/result path.
2. Remove implicit Platform Administrator tenant access; introduce explicit, audited
   tenant elevation.
3. Preserve hotel-role assignment tuples in authorization claims/policies.
4. Unify online, walk-in, assignment, cancellation, and amendment inventory locks and
   invariants.

### P1 — Financial and operational correctness

1. Implement customer Pay-at-Property plus commission receivable creation.
2. Require reconciled transactions, account for refunds, and persist complete settlement
   evidence.
3. Implement cancellation, no-show, refund initiation, and availability management.
4. Correct retry/late callback handling and persist provider-event audit records.
5. Enforce checkout balance/payment-mode invariants and check-in date/identity policy.
6. Restore housekeeping/maintenance inspection and release states; prevent direct owner
   status bypass.
7. Add transactional audit and notification outbox behavior for protected transitions.

### P2 — Actor and client completeness

1. Reconcile Owner versus Hotel Manager permissions with the approved SRS/SDD.
2. Complete staff lifecycle, profile access, room assignment, and payment collection.
3. Add owner onboarding, customer refund status, availability, and admin
   commission/reconciliation UI.
4. Restore anonymous marketplace browsing and disable cleartext in production.
5. Replace local-only saved/notification state with documented server-backed behavior.

### P3 — Regression protection and maintainability

1. Add domain/application unit tests for every booking, payment, finance, and room-state
   transition.
2. Add integration tests for tenant isolation, cross-channel inventory, idempotent
   callbacks, cancellation/refund, and settlement calculations.
3. Add mobile routing and API-contract tests for each required actor.
4. Align global.json, project target, compose assets, dependency references, and local
   setup documentation.

## 12. Open questions requiring product/document decisions

1. Is simulate-payment-success intentionally part of a classroom/demo mode? If so, what
   immutable environment and authorization guard defines that mode?
2. Does the SRS permission marker L imply a future fine-grained permission system beyond
   roles, or should current roles be treated as the complete authorization model?
3. Which management capabilities are approved for Hotel Manager versus Hotel Owner?
4. May SRS screens be consolidated when behavior is complete, and which screen IDs remain
   mandatory as independent navigation destinations?
5. Are saved hotels and notifications intentionally local demo features, or must they
   synchronize across devices as the documents imply?
6. Which identity document types and hotel-level mandatory rules must check-in enforce?
7. For future-date availability, how should current Dirty, Cleaning, or
   InspectionRequired state interact with forecast saleability?

## 13. Conclusion

The implementation is a substantial prototype with many documented happy paths, but the
current payment, tenant authorization, inventory, finance, and room-lifecycle behavior
does not yet satisfy the SRS/SDD as a production marketplace. The three critical findings
should block release. High-severity finance and lifecycle gaps should be resolved before
expanding UI coverage, and each correction should be protected by requirement-level
automated tests.
