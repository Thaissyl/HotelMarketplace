# ALN-002 Unified Inventory Commitment

Date: 2026-07-19

Branch: `fix/aln-002-unified-inventory-commitment`

## Objective

Ensure that marketplace bookings, Walk-in bookings, room assignment, and hold
expiration cannot commit more rooms than valid inventory or produce overlapping
physical-room assignments.

## Lock Hierarchy

The shared room-type resource is:

```text
inventory:room-type:{hotelId}:{roomTypeId}
```

The key intentionally excludes dates. Different date windows may overlap, so all
commitment changes for one hotel room type are serialized. Multi-room-type lock
acquisition is ordered by HotelId and RoomTypeId. Physical-room locks are acquired
only after the room-type lock.

Current write order:

1. Marketplace booking: transaction, room-type inventory lock, evaluation, insert.
2. Walk-in: transaction, room-type inventory lock, evaluation, physical-room locks,
   overlap validation, insert and assignment.
3. Check-in: transaction, booking lock, room-type inventory lock, physical-room
   locks, overlap validation, assignment.
4. Expiration: transaction, ordered room-type locks, expire holds.

Cancellation is not yet exposed by the application. ALN-005 must use this same
coordinator before releasing a commitment.

## Commitment Calculation

Committed quantity includes:

- PendingPayment bookings whose hold has not expired.
- Confirmed bookings.
- CheckedIn bookings.

Valid inventory excludes:

- Maintenance, OutOfService, Blocked, and Inactive physical rooms.
- Physical-room or room-type RoomAvailability records with Closed or Blocked
  status over an intersecting date range.
- Dirty, Cleaning, and InspectionRequired rooms for a stay beginning today.

The marketplace search and hotel-detail projections use the same status and block
rules. Transient operational states are not subtracted twice when an active booking
already represents an occupied room.

## Acceptance Evidence

| Scenario | Result |
| --- | --- |
| Eight concurrent marketplace requests for the last room | Exactly one succeeds |
| Marketplace and Walk-in compete for the last room | Exactly one succeeds |
| Two different but overlapping date windows compete | Exactly one succeeds |
| A physical-room block covers the requested dates | Booking returns 409 |
| Concurrent check-in attempts assign a physical room | Exactly one succeeds |

## Verification

```powershell
dotnet build .\backend\HotelMarketplace.slnx --no-restore
dotnet test .\backend\tests\Api.IntegrationTests\Api.IntegrationTests.csproj --no-build
```

Build result: 0 warnings and 0 errors.

Integration result: 14 passed, 0 failed, 0 skipped.
