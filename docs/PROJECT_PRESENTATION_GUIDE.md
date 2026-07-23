# Hotel Marketplace Management System - Presentation Guide

## 1. Project Overview

Hotel Marketplace Management System is a multi-tenant platform that combines a
customer hotel marketplace with daily hotel operations and platform-level
administration.

The system solves three connected problems:

1. Customers need to search, compare, reserve, and manage hotel stays.
2. Hotels need one operational workspace for inventory, front desk,
   housekeeping, maintenance, staff, and cash collection.
3. The platform operator needs centralized hotel approval, user administration,
   commission, reconciliation, refund, settlement, and audit visibility.

The current product is an academic MVP. It contains a working ASP.NET Core API,
a Flutter Android client, a SQL Server database running in Docker, automated
tests, local seed data, and development scripts.

## 2. Main Scope Decisions

The following decisions define the implemented scope:

- The marketplace supports hotels and private rooms.
- Data and permissions are isolated by hotel in a multi-tenant model.
- Online reservations use a fifteen-minute inventory hold while awaiting demo
  payment.
- Payment is an explicit in-app demonstration. No real bank or payOS transaction
  is performed.
- Pay-at-property and walk-in cash collection are recorded by Front Desk staff.
- Walk-in reservations use the protected `Anonymous Walk-in Customer` account,
  preserve guest details on each booking, and do not enter `PendingPayment`.
- Refunds, reconciliation, and settlements are manual workflows in the MVP.
- A Platform Administrator can inspect and administer platform data but does not
  automatically receive hotel operational permissions.

## 3. System Actors

| Actor | Main responsibility |
| --- | --- |
| Guest | Browse and search published hotels without signing in. |
| Customer | Manage an account, save hotels, create reservations, confirm demo payment, cancel eligible bookings, and view trips and notifications. |
| Property Owner | Register and configure hotels, inventory, room types, rooms, content, and hotel staff. |
| Hotel Manager | Supervise Front Desk, availability, housekeeping, maintenance, and eligible operational staff. |
| Receptionist | Manage arrivals, room assignment, check-in, checkout, no-show, payment collection, and walk-in guests. |
| Housekeeping Staff | Claim and progress cleaning tasks until a room becomes available again. |
| Maintenance Staff | Report, claim, repair, and resolve room maintenance requests. |
| Platform Administrator | Review hotels, manage platform users, inspect finance, reconcile transactions, and process refunds and settlements. |

## 4. Technology Stack

| Layer | Technology |
| --- | --- |
| Mobile client | Flutter and Dart |
| Mobile state management | Riverpod |
| Mobile navigation | GoRouter with role-aware guards |
| Mobile networking | Dio with authentication and hotel-scope interceptors |
| Secure mobile storage | Flutter Secure Storage |
| Backend | ASP.NET Core Web API, C#, .NET 8 |
| Architecture | Clean Architecture with Domain-Driven Design and use-case services |
| Persistence | Entity Framework Core with Fluent API mappings |
| Database | Microsoft SQL Server 2022 |
| Authentication | JWT Bearer authentication and secure password hashing |
| Local infrastructure | Docker Compose with a persistent SQL Server volume |
| Testing | xUnit, FluentAssertions, WebApplicationFactory, Testcontainers, and Flutter Test |

## 5. High-Level Architecture

```text
Flutter Mobile Application
        |
        | HTTPS/JSON + JWT + X-Hotel-Id
        v
ASP.NET Core Presentation.Api
        |
        v
Application Use Cases and Validation
        |
        v
Domain Entities and Business Rules
        |
        v
Infrastructure.Persistence -> SQL Server 2022

Supporting adapters:
- Infrastructure.Scheduling: expired booking background worker
- Infrastructure.Notification: durable notification recording and dispatch
- SharedKernel: result, exception, clock, and shared primitives
```

The dependency direction points inward. Domain code does not depend on HTTP,
Flutter, EF Core, SQL Server, or other infrastructure concerns.

## 6. Backend Structure

| Project | Responsibility |
| --- | --- |
| `Presentation.Api` | Controllers, HTTP contracts, Swagger, authentication, authorization, and global error responses. |
| `Application` | Use cases, request and response DTOs, validation, orchestration, and application contracts. |
| `Domain` | Entities, enums, state transitions, invariants, and hotel-scoped domain concepts. |
| `Infrastructure.Persistence` | DbContext, repositories, SQL transactions, EF Core mappings, query filters, and migrations. |
| `Infrastructure.Notification` | Notification persistence and delivery abstraction. |
| `Infrastructure.Scheduling` | Periodic expiration of unpaid reservations. |
| `SharedKernel` | Shared result pattern, exceptions, base entity abstractions, and date-time provider. |

Important domain groups include accounts and roles, hotels and amenities, room
types and physical rooms, availability restrictions, bookings and assignments,
guest stays, invoices and payment collections, housekeeping, maintenance,
notifications, audit records, commissions, refunds, and settlements.

## 7. Mobile Structure

```text
mobile/lib/
  app/          App bootstrap, routing, theme, and design system
  core/         Network, secure storage, environment, errors, and DI providers
  features/     Account, auth, bookings, customer, marketplace, operations,
                platform administration, and system screens
  shared/       Reusable widgets, formatters, and common UI models
```

The mobile client provides:

- Secure session restoration and logout.
- Role-aware routing after login.
- Centralized mapping of API failures into user-friendly messages.
- Automatic JWT and `X-Hotel-Id` headers.
- Public search, hotel details, saved hotels, booking, trips, notifications, and
  account settings.
- Role-specific workspaces for hotel operations and platform administration.
- Pagination, filtering, loading states, empty states, duplicate-submit
  protection, and responsive operation controls.

## 8. Core Business Flows

### 8.1 Authentication and Session

1. A user registers as a Customer or signs in with an existing account.
2. The API validates input and verifies the password hash.
3. The API returns a JWT containing identity, role, and authorized hotel data.
4. Flutter stores the token in secure storage.
5. Dio attaches the token to protected requests.
6. A role-aware router opens the correct Customer, hotel operations, or Platform
   Administrator workspace.
7. A rejected or expired session is cleared globally and returns to login.

### 8.2 Hotel Onboarding and Inventory

1. A Property Owner registers a hotel.
2. The hotel starts in a review state and is not visible in the marketplace.
3. The owner configures hotel profile, content, room types, pricing, capacity,
   physical rooms, and staff assignments.
4. A Platform Administrator approves or rejects the registration.
5. Only approved and published hotels appear in public search.

### 8.3 Marketplace Search and Booking

1. A Guest or Customer searches by location, dates, guest count, and room count.
2. SQL projections return only approved hotels and room types with sufficient
   date-range availability.
3. The Customer selects a room type and submits a booking.
4. A Serializable transaction and SQL application lock serialize competing
   reservations for the same room inventory.
5. If inventory is available, the booking enters `PendingPayment` and holds the
   requested quantity for fifteen minutes.
6. Demo payment confirms the booking idempotently without contacting a bank.
7. If payment is not confirmed, a background service expires the booking and
   releases its inventory.

### 8.4 Front Desk Stay Lifecycle

```text
Confirmed
   -> room assignment and Check-in
CheckedIn
   -> Checkout
Completed
   -> Housekeeping task created
Physical room: Occupied -> Dirty/Housekeeping -> Available
```

Receptionists can inspect arrivals, checked-in guests, departures, history, room
availability, payment collections, and no-show eligibility. State-changing
operations execute inside protected transactions to prevent double assignment,
double check-in, or concurrent checkout conflicts.

### 8.5 Walk-In Booking

1. Reception staff selects a room type and optional physical room.
2. The API locks the same inventory used by online booking.
3. The booking is attributed to `Anonymous Walk-in Customer`, while the actual
   guest name and contact remain booking-specific.
4. Cash collection is recorded immediately.
5. The booking becomes `CheckedIn` when a room is assigned, or `Confirmed` when
   assignment is deferred.
6. It never receives a payment countdown.

### 8.6 Housekeeping

1. Checkout creates a cleaning task and places the physical room into a
   non-sellable cleaning state.
2. An eligible worker claims the task.
3. The task progresses from waiting to in progress and completed.
4. Completion returns the room to `Available`, subject to the workflow rules.
5. Managers can assign work, but staff cannot silently take over another active
   worker's task.

### 8.7 Maintenance

1. Authorized hotel staff reports an issue against a physical room.
2. The room becomes `Maintenance` or `OutOfService` and is removed from sellable
   inventory.
3. Maintenance staff claims and starts the repair.
4. Resolution records the workflow result and releases the room according to its
   operational state rules.

### 8.8 Platform Administration and Finance

The Platform Administrator workspace provides:

- User search, role/status filtering, suspension, reactivation, and activity
  history.
- Hotel registration review, approval, rejection, and commission configuration.
- Platform financial summaries and payment reconciliation.
- Manual settlement creation and status transitions.
- Manual refund review and status transitions.

The financial model separates gross booking value, platform commission, hotel
net amount, collection method, reconciliation state, and settlement state.

## 9. Multi-Tenant Security

Hotel isolation is enforced at several levels:

1. JWT claims identify the authenticated account and roles.
2. The request hotel is resolved from the route first, then `X-Hotel-Id`, then
   the query string where supported.
3. The `HotelScoped` authorization policy verifies an active assignment and a
   compatible hotel role.
4. EF Core global query filters automatically constrain hotel-scoped entities.
5. Application use cases re-check ownership and business authority for sensitive
   mutations.
6. Integration tests cover forged hotel headers, cross-hotel access, revoked
   assignments, and insufficient operational roles.

Platform Administrator authority is intentionally separated from hotel staff
authority. Being a global administrator does not grant permission to check in a
guest, clean a room, or resolve a maintenance task.

## 10. Data Integrity and Concurrency

The main consistency controls are:

- SQL Server transactions for booking, cancellation, payment, check-in,
  checkout, availability, refund, and settlement transitions.
- Serializable isolation for inventory-sensitive workflows.
- SQL application locks for competing inventory and stay operations.
- Database uniqueness constraints for identities and durable account data.
- Domain state-transition methods that reject invalid lifecycle changes.
- Idempotent demo payment and saved-hotel operations.
- Server-calculated amounts; clients cannot choose the payment amount.
- A periodic background worker that expires unpaid reservations in batches.

These controls prevent common failures such as overbooking the last room,
confirming payment twice, double check-in, assigning one physical room twice,
or mutating a completed/cancelled booking.

## 11. Error Handling and Validation

- Request DTOs validate required values, formats, ranges, dates, room counts,
  guest counts, email addresses, passwords, and ten-digit phone numbers where
  applicable.
- EF Core uses parameterized queries, which prevents SQL injection through normal
  API inputs.
- The API returns standardized Problem Details responses.
- Global exception handling maps validation, authorization, conflict, missing
  resource, and server failures without exposing stack traces, SQL, or secrets.
- Flutter maps status codes and Problem Details into friendly, actionable UI
  messages.
- Submit buttons are disabled while a request is in progress to reduce accidental
  duplicate actions.

## 12. Database and Infrastructure

SQL Server 2022 runs through `docker-compose.yml` with:

- A named persistent volume.
- A health check.
- Environment-based credentials stored in the ignored local `.env` file.
- EF Core migrations as the single schema management mechanism.
- Backup and restore scripts for the local database.

The repository currently contains 27 EF Core migration source files, including
migration metadata and the model snapshot. The startup script checks Docker,
waits for SQL Server, applies pending migrations, and then starts the API.

## 13. Automated Quality Evidence

The latest documented verification baseline reports:

| Test area | Result |
| --- | --- |
| Domain tests | 25 passed |
| Application tests | 2 passed |
| API integration tests | 40 passed |
| Flutter tests | 14 passed |
| Backend build | Passed with zero warnings and zero errors |
| Flutter static analysis | Passed with no issues |
| Android debug build | Passed |
| EF Core model check | Database model matches the latest migration |

Important automated scenarios include:

- Register/login validation and unauthorized access.
- Forged `X-Hotel-Id` and cross-hotel data access.
- Online booking and walk-in booking inventory contention.
- Last-room overbooking prevention under concurrent requests.
- Payment versus cancellation concurrency.
- Duplicate and concurrent demo payment confirmation.
- Expired booking check-in rejection.
- Concurrent room assignment and check-in protection.
- Cancellation, refund, no-show, availability restriction, housekeeping, and
  maintenance state transitions.
- Saved hotel and notification account isolation.
- Flutter contract parsing and booking countdown disposal.

## 14. Local Demonstration

From the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\start-local-backend.ps1
```

Useful addresses:

- API: `http://localhost:5080`
- Swagger: `http://localhost:5080/swagger`
- Health check: `http://localhost:5080/health`
- Android emulator API address: `http://10.0.2.2:5080`

Run the mobile app in profile mode for a smoother demonstration:

```powershell
cd D:\HotelMarketplace\mobile
flutter run --profile -d emulator-5554 --dart-define API_BASE_URL=http://10.0.2.2:5080
```

Seed or reset the demonstration accounts and business data:

```powershell
cd D:\HotelMarketplace
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\seed-local-test-accounts.ps1
```

All seeded accounts use password `Test@123`:

| Role | Email |
| --- | --- |
| Customer | `customer@test.com` |
| Property Owner | `owner@test.com` |
| Hotel Manager | `manager@test.com` |
| Receptionist | `reception@test.com` |
| Housekeeping Staff | `housekeeping@test.com` |
| Maintenance Staff | `maintenance@test.com` |
| Platform Administrator | `admin@test.com` |

## 15. Recommended Presentation Flow

A concise presentation can follow this order:

1. Explain the problem: marketplace booking and hotel operations are connected
   but serve different users.
2. Show the architecture diagram and Clean Architecture dependency direction.
3. Demonstrate public hotel search and Customer booking.
4. Confirm demo payment and explain the fifteen-minute hold and concurrency lock.
5. Sign in as Receptionist, assign a physical room, and check in the guest.
6. Checkout and show the automatically created housekeeping task.
7. Sign in as Housekeeping Staff and return the room to available inventory.
8. Briefly show Maintenance and its effect on room availability.
9. Sign in as Platform Administrator and show hotel approval, users, finance,
   refunds, and settlements.
10. Finish with tenant security and automated test evidence.

## 16. Suggested Oral Summary

> Our project is a multi-tenant hotel marketplace and operations management
> system. Customers can search approved hotels, reserve available room types,
> confirm a simulated payment, and manage their trips. Hotel owners and managers
> configure properties, inventory, and staff, while Receptionist, Housekeeping,
> and Maintenance roles execute the daily stay lifecycle. Platform Administrators
> review hotels and manage platform-level finance without automatically gaining
> hotel operational authority. The backend uses ASP.NET Core, Clean Architecture,
> Domain-Driven Design, EF Core, and SQL Server. The Flutter application uses
> Riverpod, GoRouter, Dio, and secure storage. Hotel data is protected by JWT,
> role policies, hotel-scoped authorization, and global query filters. Critical
> booking and room operations use transactions and SQL locks to prevent
> overbooking and conflicting state changes.

## 17. MVP Limitations and Production Readiness

The system is ready for an academic MVP demonstration, but it should not be
described as fully production-ready.

Current limitations include:

- Payment is simulated and does not contact a real financial provider.
- Refunds, reconciliation, and settlements are manual.
- Saved hotels and notifications are durable, but some optional engagement and
  reporting experiences remain basic.
- Operational history, charts, maintenance attachments, and advanced hotel
  analytics can be expanded.
- Production deployment, managed backups, mobile HTTPS enforcement, rate
  limiting, refresh-token rotation, monitoring, and disaster recovery require a
  separate production phase.

The correct conclusion is: the core MVP business flows, security boundaries,
database consistency mechanisms, mobile role routing, and automated critical
tests are implemented and suitable for demonstration; production hardening is a
future phase.

## 18. Likely Questions and Answers

### Why use Clean Architecture?

It keeps business rules independent from HTTP, database, and UI frameworks. This
makes state transitions easier to test and reduces the cost of replacing an
infrastructure component.

### How does the system prevent overbooking?

Availability is checked and the booking commitment is created in one
Serializable SQL transaction. A SQL application lock serializes competing
requests for the same inventory scope, so only requests with remaining capacity
can commit.

### Why use room types for booking and physical rooms for check-in?

Customers reserve a category and quantity, while hotels assign exact room
numbers close to arrival. This hybrid model matches real hotel operations and
avoids unnecessary early room assignment.

### How is one hotel's data protected from another hotel?

The API combines JWT roles, active hotel staff assignments, the `HotelScoped`
policy, request hotel resolution, EF Core global query filters, and use-case
ownership checks. Forged hotel headers and cross-hotel requests are covered by
integration tests.

### Why is payment only a demonstration?

Real payment integration was explicitly excluded from the current scope. The
demo flow still enforces booking ownership, valid state, expiry, server-side
amount calculation, idempotency, transaction recording, commission, audit, and
notification rules.

### What happens after checkout?

The booking is completed, collection and invoice information are finalized, the
physical room becomes unavailable for cleaning, and a housekeeping task is
created. Completing that task returns the room to available inventory.

### Can Platform Administrators operate any hotel?

No. They have platform-level visibility and administration. Operational actions
require an explicit hotel assignment and the relevant hotel role.

### What proves the system is stable?

The repository has passing backend builds, static Flutter analysis, Android
build verification, Domain and Application tests, 40 SQL Server-backed API
integration tests, and 14 Flutter tests. The integration suite includes security,
concurrency, tenant isolation, and lifecycle failure cases.
