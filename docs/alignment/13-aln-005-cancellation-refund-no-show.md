# ALN-005 Cancellation, Refund Initiation, and No-Show

## Customer Cancellation Contract

- A Customer may request a cancellation quote and cancel only their own
  `PendingPayment` or `Confirmed` booking.
- The quote is calculated by the server from payment state, payment mode, stay
  dates, and the hotel's cancellation policy. The mobile client never calculates
  refund eligibility independently.
- An unpaid cancellation releases inventory without creating a refund.
- A paid Platform Collect cancellation inside the configured free-cancellation
  window creates one `RefundRecord` in `PendingReview`. The requested amount is
  the booking total multiplied by the configured refund percentage.
- Missing policy, late cancellation, or a zero-percent policy remains
  cancellable but non-refundable.

## No-Show Contract

- Receptionist, Hotel Manager, and Property Owner may mark a hotel-scoped
  `Confirmed` booking as `NoShow` after the configured operational window.
- `Operations:NoShowEligibleAfterHours` defaults to 24 hours from the UTC
  check-in date and accepts values from 0 through 168.
- Platform Administrator does not receive operational no-show authority.
- No-show preserves existing payment and commission evidence while releasing
  inventory and active pre-assignment records.

## Atomicity and Evidence

- Demo payment, cancellation, check-in, checkout, no-show, and expiration now
  use the shared `booking:{bookingId}` SQL application-lock namespace.
- Mutation order is booking lock, room-type inventory lock, then sorted physical
  room locks.
- Cancellation and no-show update Booking state, deactivate assignments, release
  rooms in `Assigned` state, and write audit and notification records in the same
  Serializable transaction.
- A unique database index on `RefundRecords.BookingId` prevents duplicate refund
  initiation for one booking.

## API and Mobile Surface

- `GET /api/bookings/{bookingId}/cancellation-quote`
- `POST /api/bookings/{bookingId}/cancel`
- `POST /api/hotels/{hotelId}/front-desk/bookings/{bookingId}/no-show`
- Customer Trips displays policy and estimated refund before collecting a
  cancellation reason.
- Front Desk Arrival details exposes the no-show action and displays server
  eligibility errors when the configured window has not elapsed.

## Verification

- Domain tests cover valid and invalid cancellation/no-show transitions and
  physical-room assignment release.
- Integration tests cover unpaid inventory release, policy refund creation,
  foreign-customer denial, concurrent payment/cancellation consistency, early
  no-show denial, and successful no-show audit/notification evidence.
