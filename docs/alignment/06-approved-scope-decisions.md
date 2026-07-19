# Approved Scope Decisions

These project decisions were confirmed by the product owner on 2026-07-19. They
are normative inputs to the SRS, SDD, and codebase alignment audit.

## Payment

The project uses demo payment only. Integration with payOS or another real bank
or payment provider is outside the current project scope.

Demo payment is not exempt from application integrity rules. The operation must
be authenticated, restricted to the booking owner or an explicitly authorized
administrative workflow, accept only an eligible booking state, be idempotent,
record the simulated transaction, and avoid trusting an amount supplied by the
client.

## Platform Administrator Access

Platform Administrators do not automatically have authority to perform Front
Desk, Housekeeping, or Maintenance actions for a hotel.

Their platform-level scope includes:

- Macro financial and settlement information.
- Overview room and inventory information.
- Hotel registration, review, approval, and rejection information.

Operational mutations require an explicit hotel assignment and a compatible
operational role. A Platform Administrator claim by itself is insufficient.

## Walk-In Booking

The system maintains one shared system-owned customer account named
`Anonymous Walk-in Customer`. Front Desk staff map every walk-in booking to this
account while storing the actual guest details on the booking or stay record.

Cash is treated as collected at the front desk during the walk-in flow. The
booking therefore:

- Never enters `PendingPayment`.
- Has no fifteen-minute payment expiration or countdown.
- Becomes `CheckedIn` when physical rooms are assigned during creation.
- Becomes `Confirmed` when creation is completed without physical-room
  assignment, and later follows the normal assignment and check-in transition.

The shared account does not merge guest identity, stay history, invoices, or
contact details. Those records remain booking-specific. Walk-in inventory checks
must participate in the same room-type and physical-room concurrency controls as
online reservations.
