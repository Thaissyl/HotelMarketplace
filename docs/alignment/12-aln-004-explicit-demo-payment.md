# ALN-004 Explicit Demo Payment

## Approved Scope

This project does not contact payOS, a bank, or any external payment gateway.
Platform Collect bookings retain the fifteen-minute hold, but confirmation uses
the authenticated in-app demo endpoint and never charges real money.

## Runtime Contract

- Configuration declares `Payment:Mode` as `Demo`; unsupported modes fail during
  startup instead of silently selecting an incomplete integration.
- `POST /api/bookings/{bookingId}/demo-payment` requires a Customer JWT and the
  amount displayed by the client.
- The server verifies booking ownership, `PlatformCollect` mode,
  `PendingPayment` status, unexpired deadline, and exact server-calculated amount.
- One Serializable transaction and booking application lock confirm the booking,
  record provider `DEMO`, create commission, write audit evidence, and enqueue a
  customer notification.
- Repeated or concurrent confirmation returns the existing paid transaction and
  does not duplicate financial or audit records.

## Removed Surface

- payOS payment-link, webhook, return, and cancel routes.
- payOS gateway abstractions, request models, validator, infrastructure project,
  DI registration, secrets, and runtime configuration.
- Gateway checkout-link metadata columns. Existing local `payOS` and `Simulated`
  provider values are normalized to `DEMO` by migration.

## Mobile Experience

The reservation hold screen labels the action `Confirm demo payment` and states
that no bank account or real money is charged. It sends the displayed booking
total for server verification and retains the existing expiration countdown.

## Verification

- Valid confirmation returns provider `DEMO` and changes the booking to
  `Confirmed`.
- Wrong amount, foreign booking, and expired hold are rejected.
- Two concurrent requests return one processed result and one idempotent
  duplicate result.
- Exactly one payment transaction, commission, audit record, and notification
  record are persisted.
- Legacy payOS webhook/return and payment-link routes return `404 Not Found`.
