# ALN-009 Transactional Audit and Notification Outbox

Status: Implemented and verified on `fix/aln-009-audit-notification-outbox`.

## Scope

ALN-009 closes GAP-017 and GAP-018 by making protected mutation audit and
notification recording a persistence invariant. External email, SMS, or push
delivery remains mocked as permitted by the MVP requirements.

## Audit Invariant

`HotelMarketplaceDbContext` inspects tracked protected entities immediately
before each save. Added, modified, and deleted account, hotel, inventory,
booking, finance, stay, housekeeping, and maintenance entities receive a concise
audit record without serializing field values or sensitive request data.

Repositories may continue to add richer workflow-specific audit summaries. When
one exists for the same target in the current save, it takes precedence over the
generic record. Both forms participate in the caller's existing transaction.

Scheduler activity uses a nullable `ActorUserAccountId`. This distinguishes a
system action from a human action without creating a login-capable synthetic
user. The schema migration makes the foreign key optional, and the Admin activity
projection retains its existing response contract for human-targeted history.

## Notification Outbox

The same save creates Pending `NotificationRecord` entries for:

- account registration;
- booking creation and status transitions;
- payment and cancellation paths already covered by explicit workflow records;
- unpaid booking expiration;
- hotel submission and approval-state changes;
- check-in, checkout, and no-show booking transitions;
- housekeeping task creation, assignment, and status changes;
- maintenance request creation, assignment, and status changes;
- refund creation or status changes;
- settlement creation or status changes.

Existing explicit notification records suppress a generic notification for the
same target during the save. Pending records are durable outbox evidence; no
claim is made that an external provider delivered them.

## Data Migration

`AddTransactionalAuditOutbox` changes `AuditRecords.ActorUserAccountId` from
required to optional. Existing human audit rows remain unchanged.

## Acceptance Evidence

- Backend build passes with zero warnings and zero errors.
- All 15 Domain tests pass.
- All 35 SQL Server API integration tests pass.
- Lifecycle assertions cover booking, stay, assignment, invoice, housekeeping,
  checkout notification, and housekeeping notification evidence.
- Expiration assertions cover nullable system actor and Customer-targeted outbox
  evidence.
- EF Core reports no pending model changes.
- Flutter analysis, four tests, and debug APK build pass unchanged.

## Residual Scope

- External notification delivery is intentionally mocked.
- A Customer notification inbox API and Mobile view remain ALN-012 or ALN-013.
- Saved hotels remain device-local pending the ALN-013 product decision.
