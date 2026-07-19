# ALN-008 Stay and Room Lifecycle

## Scope

ALN-008 aligns check-in, physical-room assignment, cleaning, inspection,
maintenance release, and hotel setup status changes with the canonical stay and
room lifecycle requirements.

## Check-In and Identity

- A confirmed booking can be checked in only on its `CheckInDate` according to
  the server UTC date provider.
- Identity document type and number are required. A two-letter issuing country
  and a non-expired expiry date are optional.
- Identity evidence is stored only on `GuestStayRecord`; general booking and
  housekeeping projections do not expose it.
- A pre-assigned room can be used by submitting an empty room list at check-in.
  A different room selection must first use the assignment operation.

## Physical-Room Assignment

`PUT /api/hotels/{hotelId}/front-desk/bookings/{bookingId}/room-assignments`
creates or atomically replaces the active assignment for a confirmed booking.
It acquires the booking lock, room-type inventory lock, and ordered physical-room
locks before validating quantity, room type, status, and date overlap. Replaced
rooms return to `Available`; selected rooms enter `Assigned`.

## Cleaning and Inspection

`HotelProperty.RequiresRoomInspection` defaults to `true` and is configurable by
the Property Owner. Checkout still moves occupied rooms to `Dirty` and creates
cleaning tasks. Cleaning follows:

`Dirty -> Cleaning -> InspectionRequired -> Available`

When inspection is disabled, cleaning completion may move directly to
`Available`. Only an assigned Property Owner or Hotel Manager may execute the
inspection endpoint when inspection is required.

## Maintenance Release

Repair execution follows:

`Open -> InProgress -> Resolved -> Released`

Resolution requires a note and UTC timestamp. It moves the room to
`InspectionRequired` when inspection is enabled, otherwise to `Dirty` with a
post-maintenance cleaning task. Resolution never returns the room directly to
saleable inventory. Owner/Manager release is allowed only from
`InspectionRequired` or after cleaning has already made the room `Available`.

## Setup Safeguards

Hotel setup can create rooms as `Available` or `Inactive` and can only toggle
between those states. It cannot manufacture Dirty, Cleaning, Maintenance,
OutOfService, Assigned, Occupied, or InspectionRequired states. A status change
is rejected while an active assignment, housekeeping task, or maintenance
request exists.

## Verification

- Domain tests cover cleaning inspection, maintenance release, and setup bypass.
- API tests cover pre-assignment replacement, early check-in rejection, direct
  setup bypass rejection, concurrent check-in, checkout cleaning creation, and
  maintenance resolution/release.
- Migration `AlignStayAndRoomLifecycle` backfills legacy identity records before
  making identity type and number required.
- Mobile exposes identity capture, pre-assignment/change-room, inspection state,
  maintenance resolution evidence, controlled release, and owner policy setup.

Remaining work is explicit: housekeeping and maintenance assignee ownership is
GAP-025, audit/outbox completeness is ALN-009, and hotel-local timezone modeling
remains a future operational enhancement.
