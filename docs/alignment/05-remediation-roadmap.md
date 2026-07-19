# Remediation Roadmap

This roadmap aligns the implementation with the canonical SRS and SDD subject
to the approved demo-payment, Platform Administrator, and Walk-in decisions.
Each change should be implemented on a focused branch and merged only after its
acceptance tests pass.

## P0: Shared Integrity Foundations

### ALN-001 Hotel-Role Authorization Model

Status: Implemented and verified on `fix/aln-001-hotel-role-authorization`.
See [09-aln-001-hotel-role-authorization.md](09-aln-001-hotel-role-authorization.md).

- Remove unconditional Platform Administrator access from
  `HotelAccessAuthorizer`, operational services, and operational controllers.
- Represent active hotel assignments as `(hotelId, role)` claims or resolve them
  server-side from a short-lived session identifier.
- Keep platform governance permissions separate from hotel operational roles.
- Add tests for forged headers, unassigned Platform Admin, mixed-role users, role
  revocation, and same user with different roles at different hotels.

Acceptance: no token can perform an operation at a hotel unless it proves an
active compatible role for that exact hotel.

### ALN-002 Unified Inventory Commitment

Status: Implemented and verified on `fix/aln-002-unified-inventory-commitment`.
See [10-aln-002-unified-inventory-commitment.md](10-aln-002-unified-inventory-commitment.md).

- Introduce a shared inventory reservation coordinator used by marketplace,
  Walk-in, room assignment, cancellation, expiration, and no-show.
- Use one compatible application-lock resource for hotel, room type, and
  overlapping date range, followed by physical-room locks when assignment is
  requested.
- Include PendingPayment holds, Confirmed bookings, CheckedIn stays,
  RoomAvailability blocks, and operationally unsellable rooms.
- Add cross-channel concurrency tests where online and Walk-in requests compete
  for the final room.

Acceptance: committed quantity never exceeds valid inventory and a physical room
never has overlapping active assignments.

### ALN-003 Approved Walk-In Model

Status: Implemented on `fix/aln-003-approved-walk-in-model`.

- Add a protected seeded system account `Anonymous Walk-in Customer` with a
  stable identifier and no interactive login capability.
- Store real guest identity and contact information on the booking/stay.
- Record source `WalkIn`, payment mode `PayAtProperty`, and cash collection.
- Enter `CheckedIn` only when assignment occurs; otherwise enter `Confirmed`.
- Never set payment expiration or `PendingPayment` for Walk-in.

Acceptance: Walk-in is traceable, financially recorded, inventory-safe, and does
not attribute the booking to the staff member.

### ALN-004 Explicit Demo Payment

Status: Implemented on `fix/aln-004-explicit-demo-payment`.

- Treat simulated payment as the approved gateway adapter for this project.
- Rename user-facing behavior to Demo Payment and record provider `DEMO`.
- Verify booking ownership, eligible state, expiration, server-side amount, and
  idempotency under one transaction.
- Audit confirmation and test duplicate, expired, foreign-booking, and concurrent
  confirmation attempts.
- Remove or isolate payOS routes/configuration so documentation and runtime expose
  one coherent payment model.

Acceptance: demo confirmation cannot alter another user's booking, cannot revive
an expired booking, and cannot duplicate payment or commission records.

## P1: Core Business Lifecycles

### ALN-005 Cancellation, Refund Initiation, and No-Show

Status: Implemented and verified on `fix/aln-005-customer-cancellation`.
See [13-aln-005-cancellation-refund-no-show.md](13-aln-005-cancellation-refund-no-show.md).

Implement policy-aware cancellation, refund creation/status, no-show eligibility,
inventory release, assignment release, financial trace, audit, notification, API,
mobile views, and tests.

### ALN-006 Availability Calendar

Status: Implemented and verified on `fix/aln-006-availability-calendar`.
See [14-aln-006-availability-calendar.md](14-aln-006-availability-calendar.md).

Implement date-range room-type or physical-room blocking, conflict checks against
active commitments, marketplace projection integration, Owner/Manager management,
limited Receptionist permissions, and mobile calendar behavior.

### ALN-007 Dual Collection and Finance Invariants

Status: Implemented and verified on `fix/aln-007-dual-collection-finance`.
See [15-aln-007-dual-collection-finance.md](15-aln-007-dual-collection-finance.md).

Add Customer Pay at Property, collection-specific lifecycle, commission
receivable/deducted states, type-specific settlement eligibility, refund-aware
amounts, reconciliation exception notes, immutable settlement evidence, and
complete invoice/folio balance facts.

### ALN-008 Stay and Room Lifecycle

Status: Implemented and verified on `fix/aln-008-stay-room-lifecycle`.
See [16-aln-008-stay-room-lifecycle.md](16-aln-008-stay-room-lifecycle.md).

Enforce check-in date/identity rules, pre-assignment/change-room, checkout balance,
Dirty to Cleaning to InspectionRequired/Available policy, maintenance completion
versus room release, and protection from direct setup-status bypass.

### ALN-009 Audit and Notification Outbox

Status: Implemented and verified on `fix/aln-009-audit-notification-outbox`.

Create audit and notification records in the same transaction as every protected
mutation. External notification delivery may remain mocked.

## P2: Actor and Mobile Completeness

### ALN-010 Owner, Manager, and Staff Lifecycle

Status: Staff lifecycle implemented and verified on `feat/aln-010-staff-lifecycle`;
delegated Manager hotel and inventory setup remains pending.

Implemented approved Hotel Manager management permissions, create-account and
attach-existing-user flows, deactivate/reactivate, role reassignment, tuple-aware
revocation, transactional concurrency safeguards, API operations, and Mobile
staff management. Delegated profile and inventory setup remains GAP-019, while
role-neutral own-profile management remains GAP-021.

### ALN-011 Contract and Data Completeness

Persist GuestCount and add hotel images, amenities, cancellation policy, room
floor/notes/facilities, payment collection evidence, reconciliation notes, and
settlement evidence through domain, migrations, DTOs, and projections.

### ALN-012 Mobile Requirement Parity

- Permit Guest marketplace and hotel-detail access.
- Add Owner hotel registration/onboarding.
- Add cancellation and refund status.
- Add availability calendar and no-show candidates.
- Add commission and reconciliation admin views.
- Show only role-relevant operations and protect sensitive guest/finance data.
- Disable cleartext in release builds and validate production HTTPS.

## P3: Quality and Operational Closure

### ALN-013 Durable User Features and Reporting

Decide whether saved hotels and notifications are retained; if retained, make
them server-backed. Complete documented dashboard metrics and filters.

### ALN-014 Requirement-Level Test Suite

Add Domain and Application tests for every lifecycle transition; API tests for
tenant boundaries, concurrency, cancellation, refund, settlement, collection,
audit, and scheduler behavior; Flutter tests for guards, role landing, forms,
duplicate submission, timer disposal, and API contracts.

### ALN-015 Toolchain and Operations

Status: Implemented and verified on `fix/aln-015-release-readiness`.

Align `global.json` with .NET 8, remove unnecessary Scheduling-to-Persistence
dependency, repair compose/documentation drift, document backup/restore, and run
all builds, static analysis, migrations, integration tests, and mobile tests from
a clean checkout.

## Implementation Order

1. ALN-001 through ALN-004.
2. ALN-005 through ALN-009.
3. ALN-010 through ALN-012.
4. ALN-013 through ALN-015.

Database migrations should be additive until data backfills and compatibility
checks complete. API contract changes used by mobile should be introduced before
the corresponding client update, with temporary compatibility only where an
existing demo flow must remain runnable during the branch.
