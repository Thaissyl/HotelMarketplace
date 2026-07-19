# Consolidated Alignment Audit Summary

## Executive Assessment

The implementation is a credible classroom MVP with a functioning vertical
slice across marketplace, booking, Front Desk, housekeeping, maintenance, and
platform administration. It is not yet aligned with the canonical SRS and SDD.
The primary issue is not code style; it is behavioral divergence across tenant
authorization, inventory commitments, lifecycle rules, finance records, role
capabilities, and mobile entry flows.

The approved demo-payment decision removes real payOS integration from the
required remediation scope. It does not remove Pay at Property, commission,
refund, settlement, ownership, idempotency, or audit requirements.

## Conformance Snapshot

| Classification | Main contents |
| --- | --- |
| Substantially aligned | Registration validation, password hashing, public backend marketplace, owner hotel registration backend, hotel approval, background expiration, basic projected read queries, basic check-in concurrency, and checkout-to-housekeeping creation |
| Partial | Login claims, marketplace details, Customer booking, booking history, hotel and room management, Front Desk lists, check-in, checkout, staff management, housekeeping, maintenance, platform dashboard, reconciliation, and mobile role workspaces |
| Missing | Cancellation, no-show, availability calendar management, complete staff lifecycle, production refund initiation, notification creation, broad operational audit, and multiple required mobile equivalents |
| Behaviorally unsafe | Platform Admin tenant bypass, cross-channel online/walk-in overbooking, role/hotel claim separation, owner room-status bypass, premature settlement, and direct maintenance-to-Available release |

## Release Position

The system is suitable for a controlled demonstration after known demo data and
flows are prepared. It should not be described as fully SRS/SDD-compliant or
production-ready. P0 and P1 remediation must be completed before that claim can
be made.

## Approved Product Constraints

- Demo payment remains the supported online-payment substitute.
- Platform Administrator has platform governance and approved read-only overview
  access, not implicit hotel operational mutation rights.
- Walk-in bookings use `Anonymous Walk-in Customer`, bypass `PendingPayment`, and
  enter `Confirmed` or `CheckedIn` according to room assignment.

## Highest-Risk Confirmed Gaps

1. Platform Administrator is admitted by HotelScoped policy and operational
   services without a hotel assignment.
2. JWT role claims and hotel claims are independent lists and cannot prove that a
   specific role applies to a specific hotel.
3. Marketplace reservations and Walk-in bookings do not share one inventory lock
   and committed-quantity calculation.
4. Walk-in bookings use the staff actor as the Customer and immediately occupy a
   room even for a future date.
5. Settlement may include unreconciled payment and does not correctly subtract or
   block unresolved refunds.
6. Cancellation, no-show, availability management, and refund initiation are
   missing end to end.
7. Housekeeping and maintenance collapse required inspection/release states and
   can return rooms to Available too early.
8. Operational actions are not comprehensively audited and notifications are not
   generated despite the entities existing.
9. Mobile prevents Guest marketplace browsing and cannot onboard a newly
   registered Property Owner.
10. Existing automated tests protect eight happy-path/security scenarios but not
    the principal cross-channel, finance, role-assignment, cancellation, no-show,
    audit, or mobile invariants.

## Recommended Direction

Do not rewrite the application wholesale. Preserve the existing Clean
Architecture projects and projected query patterns. Correct the shared security
and inventory foundations first, then add missing lifecycle use cases, then
complete role/mobile parity, and finally close NFR and documentation gaps. The
detailed sequence is maintained in `05-remediation-roadmap.md`.
