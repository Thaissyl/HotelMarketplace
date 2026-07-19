# ALN-007 Dual Collection and Finance Invariants

## Scope

ALN-007 aligns the approved demo-payment model with Customer Pay at Property.
It does not integrate a bank or external payment provider.

## Booking Collection Choice

- `PlatformCollect` creates `PendingPayment` with a fifteen-minute expiration.
  The authenticated no-charge Demo Payment operation confirms it.
- `PayAtProperty` becomes `Confirmed` immediately with no payment expiration.
- Both choices use the unified inventory commitment coordinator.
- Customer booking requests and Mobile confirmation explicitly carry the selected
  payment mode.

## Property Collection

`PaymentCollectionRecord` now stores method, normalized unique reference, amount,
balance before and after, status, collector, timestamp, note, and correction
evidence. Front Desk can record an independent partial or final collection only
for an eligible Pay-at-Property booking.

Recording uses a Serializable transaction and the booking application lock.
Concurrent attempts cannot exceed the server-derived outstanding balance. A
retry with the same booking, amount, method, and reference is idempotent; a
conflicting reuse of the reference is rejected.

Checkout requires exact remaining collection for Pay at Property. Platform
Collect checkout accepts no staff-entered cash and requires a paid system
transaction. The invoice can finalize only with zero balance.

## Commission and Settlement

- Platform Collect commission starts as `Deductible`.
- Pay-at-Property commission starts as `Receivable`.
- Hotel-payable settlement requires a paid and reconciled Demo transaction,
  an eligible final booking state, and no unresolved refund.
- Commission-collection settlement requires a checked-out Pay-at-Property
  booking and complete property collection.
- Processed refunds reduce settlement amounts; unresolved refunds block creation.
- Settlement items preserve booking/payment status and gross, refund, commission,
  and net snapshots.
- Finalization requires the exact expected amount, UTC date, unique reference,
  and retained source eligibility. Exception transitions require explanatory
  evidence.

Platform Admin Mobile includes reconciliation and finance-batch workflows. It
does not grant Platform Administrators hotel operational authority.

## Database Migration

`20260719112701_AlignDualCollectionFinance` adds the finance lifecycle columns,
constraints, relationships, and indexes. Existing records receive deterministic
legacy references and state backfills before unique constraints are created.

## Verification

| Check | Result |
| --- | --- |
| Backend build | Passed with 0 warnings and 0 errors |
| Domain tests | 12 passed |
| API integration tests | 33 passed against SQL Server Testcontainers |
| Migration model check | No pending model changes |
| Flutter analysis | No issues found |
| Flutter tests | 4 passed |
| Android debug build | APK built successfully |

Coverage includes Pay-at-Property immediate confirmation, concurrent attempts to
collect the final balance, finance summary projection, reconciliation, settlement
creation/finalization, and Domain amount/state invariants.

## Residual Work

- Mobile Front Desk does not yet expose an independent pre-checkout partial
  collection screen, although the protected API is available.
- Dedicated Mobile commission-rate administration remains in ALN-012 scope.
- A service-charge folio beyond booking amount, refund, and balance facts remains
  part of the broader stay lifecycle work.
