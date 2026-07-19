# ALN-011 Contract and Data Completeness

## Scope

ALN-011 closes GAP-023 and substantially closes GAP-024 by aligning the core
booking, hotel-content, room-type, and physical-room contracts with ENT-005
through ENT-013. The approved demo-payment model remains unchanged.

## Persisted Contracts

- Booking persists a positive `GuestCount` and exposes it to Customer and Front
  Desk reads.
- Booking snapshots cancellation-policy name, free-cancellation hours, and
  refund percentage at creation. Policy edits do not retroactively change an
  existing booking's cancellation quote.
- Hotel gallery stores ordered active image URLs.
- Amenity master data stores code, name, type, and status; hotel mappings remain
  unique and hotel scoped.
- Cancellation policy stores name, hours, refund percentage, description, and
  status.
- Room type stores facilities in addition to description and capacity.
- Physical room stores floor and operational notes.

Migration `CompleteHotelBookingContracts` backfills existing booking guest count
to one, snapshots the currently assigned hotel policy for existing bookings,
and supplies valid status/type defaults for existing content rows.

## Mutation Safety

The Owner content endpoint replaces gallery, amenity mappings, and policy in one
Serializable transaction. SQL application locks serialize mutations by hotel
and amenity code. Global amenity records are reused without allowing one hotel
owner to rename master data already used by another hotel. Lock contention is
reported distinctly from a missing hotel.

## Read Performance

Marketplace search uses one base projection plus batched cover-image and
amenity queries for all result hotel identifiers. Hotel detail uses fixed-count
projections for gallery, amenities, policy, and available room types. Neither
path performs per-hotel or per-room-type lazy loading.

## Mobile Behavior

Search cards render the server-provided cover image and amenity summary with a
fixed thumbnail size. Hotel detail renders a stable gallery, amenities,
cancellation policy, and room facilities. Owner room setup captures facilities,
floor, and notes. Image failures use a bounded fallback and do not resize the
layout.

Dedicated Mobile Owner editing for gallery, amenity mappings, and cancellation
policy remains part of ALN-012 UX parity. Delegated Hotel Manager profile and
inventory mutation remains GAP-019.

## Financial Evidence Review

ALN-007 already persists and projects collection method/reference/note,
balance-before and balance-after, void/exception corrections, payment
reconciliation status/note/time, immutable settlement item identifiers and
amount snapshots, settlement reference/date/note, and exception status. ALN-011
does not duplicate those facts in a second schema.

## Acceptance Evidence

- Domain tests reject non-positive guest count and verify content metadata.
- API integration verifies Owner content replacement, public marketplace
  projection, three-guest booking persistence, Customer Trips round-trip, and
  immutable cancellation-policy snapshot behavior.
- EF reports no pending model changes.
- Flutter contract tests parse the complete marketplace response.
- Backend build, all backend tests, Flutter analysis, Flutter tests, and Android
  debug APK build pass.
