# ALN-003 Approved Walk-In Model

## Implemented Invariants

- Every Walk-in booking references the stable `Anonymous Walk-in Customer`
  system account instead of the Front Desk actor.
- The system account has the Customer role for referential integrity, is hidden
  from Platform Admin user management, cannot be mutated through interactive
  account methods, and is rejected by authentication.
- Actual guest name, phone number, and optional identity document remain on the
  booking and guest stay records.
- Walk-in uses `PayAtProperty`, records the Front Desk actor as the cash
  collector, and requires collected cash to equal the server-calculated total.
- Walk-in never enters `PendingPayment` and never receives a payment expiration.
- A booking with all physical rooms assigned on today's arrival date becomes
  `CheckedIn`. A booking without assignment remains `Confirmed` for the normal
  assignment and check-in flow.
- Both paths reserve room-type quantity through the ALN-002 inventory lock.

## Database Impact

Migration `AddProtectedAnonymousWalkInCustomer` adds `IsSystemAccount`, seeds the
stable account, and assigns its Customer role. Existing interactive accounts
receive `false` through the migration default.

## Client Contract

The Walk-in request now separates `roomCount` from optional
`physicalRoomIds`. The Flutter Front Desk form calculates cash from current room
pricing and stay length, and clearly labels immediate check-in versus deferred
assignment.

## Verification

- Assigned Walk-in smoke flow reaches `CheckedIn`.
- Unassigned Walk-in reaches `Confirmed`, has no payment expiration, and is
  attributed to the protected system account.
- The system account cannot log in, is absent from Admin user search, and cannot
  be suspended through the Admin API.
- Incorrect cash collection is rejected.
- Marketplace and Walk-in final-room contention remains covered by ALN-002.
