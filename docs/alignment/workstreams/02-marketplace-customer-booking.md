# WS-02 Marketplace and Customer Booking

Status: Partial; core Customer lifecycle is incomplete

## Aligned Evidence

- Backend marketplace endpoints are anonymous and project directly to DTOs.
- Search validates dates, guests, and room count and filters approved/published
  hotels.
- Booking creation uses Serializable isolation plus SQL application locking and
  counts non-expired PendingPayment holds.
- Booking amount follows room price multiplied by quantity and nights.
- Explicit demo payment atomically validates ownership, amount, status, and
  deadline and records one `DEMO` transaction with audit evidence.
- Customer cancellation exposes a server-derived policy/refund quote and an
  ownership-protected transactional mutation that releases inventory.

## Verified Gaps

| Requirement | Finding | Gap |
| --- | --- | --- |
| UC-001/002 | Mobile classifies marketplace and hotel detail as Customer-only | GAP-022 |
| UC-005 | Customer booking always uses PlatformCollect; PayAtProperty cannot be selected | GAP-009 |
| UC-006 | Remediated: explicit no-charge demo payment is the only runtime payment integration | GAP-005, ALN-004 |
| UC-007 | Remediated: cancellation evaluates hotel policy, releases commitments, and creates one eligible refund | GAP-006, ALN-005 |
| UC-008 | Remediated: GuestCount is persisted and returned; marketplace detail now includes complete hotel and room content | ALN-011 |
| UC-021 | Remediated: Trips persistently displays cancellation-created refund amount and status | GAP-011, ALN-005 |

## Required Design

Keep one-room-type-per-booking. Add payment-mode selection, policy-aware
cancellation, customer refund status, and server-derived financial summaries.
Demo payment must remain idempotent and ownership-protected. Public browsing must
not require authentication; only booking and account actions do.

ALN-011 additionally snapshots the applicable cancellation policy when a booking
is created, so later hotel-policy edits cannot retroactively alter that booking.
