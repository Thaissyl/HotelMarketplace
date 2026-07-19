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

## Verified Gaps

| Requirement | Finding | Gap |
| --- | --- | --- |
| UC-001/002 | Mobile classifies marketplace and hotel detail as Customer-only | GAP-022 |
| UC-005 | Customer booking always uses PlatformCollect; PayAtProperty cannot be selected | GAP-009 |
| UC-006 | Remediated: explicit no-charge demo payment is the only runtime payment integration | GAP-005, ALN-004 |
| UC-007 | Cancellation, policy evaluation, inventory release, and refund initiation are absent | GAP-006 |
| UC-008 | GuestCount is hard-coded to one and booking detail is incomplete | GAP-023, GAP-024 |
| UC-021 | Customer cannot see refund status because normal behavior cannot create a refund | GAP-011, GAP-027 |

## Required Design

Keep one-room-type-per-booking. Add payment-mode selection, policy-aware
cancellation, customer refund status, and server-derived financial summaries.
Demo payment must remain idempotent and ownership-protected. Public browsing must
not require authentication; only booking and account actions do.
