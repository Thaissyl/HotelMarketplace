# ALN-006 Availability Calendar

Status: Implemented and verified on `fix/aln-006-availability-calendar`

## Scope

ALN-006 remediates GAP-008 and the SCR-019 portion of GAP-027. It implements
hotel-scoped availability reads and mutations, role-specific permissions,
date-range restriction management, active-commitment conflict protection,
marketplace consistency, Mobile operations behavior, audit evidence, and tests.

## Permission Model

| Hotel role | Read calendar | Room-type close/open | Physical-room block/unblock |
| --- | --- | --- | --- |
| PropertyOwner | Yes | Yes | Yes |
| HotelManager | Yes | Yes | Yes |
| Receptionist | Yes | No | Yes |
| PlatformAdministrator without hotel assignment | No | No | No |

The Receptionist interpretation follows the SRS permission matrix statement that
the role may receive limited operational block/unblock permission. A Receptionist
must select one physical room and cannot remove an entire room type from sale.

## Domain and Data Model

- `RoomAvailability` stores only effective `Closed` or `Blocked` intervals.
- Open availability is represented by the absence of a matching restriction.
- Every persisted restriction requires a reason of at most 500 characters.
- Open and unblock changes remove the selected interval portion. Partial removal
  splits an existing restriction into left and right intervals where necessary.
- Migration `20260719102729_AddRoomAvailabilityReason` adds the required reason
  column and backfills existing rows with `Legacy availability restriction`.

## Transaction and Concurrency

Changes execute in a serializable SQL Server transaction and acquire locks in the
same order used by booking and room assignment:

1. Shared room-type inventory application lock.
2. Physical-room application lock when a room is selected.
3. Hotel, room-type, room, active-booking, and interval validation.
4. Restriction interval mutation and audit insertion.
5. One database save and transaction commit.

Close or block is rejected when an overlapping `PendingPayment`, `Confirmed`, or
`CheckedIn` commitment exists. Pending holds that have expired are ignored. This
conservative rule prevents inventory reduction underneath an existing booking or
assignment; controlled relocation exceptions remain outside this package.

## API Contract

- `GET /api/hotels/{hotelId}/availability`
- `POST /api/hotels/{hotelId}/availability/changes`

Calendar responses project room types, physical rooms and lifecycle states,
restriction intervals, active booking codes and quantities, and assigned room
identifiers. They do not expose guest identity or platform finance data.

## Mobile Behavior

The operations dashboard exposes an `Availability` tab for Owner, Manager, and
Receptionist roles. It provides:

- Hotel context inherited from the existing hotel selector.
- Date-range, room-type, and physical-room filters.
- Summary counts and a horizontally scrollable date strip.
- Restriction details with dates and operational reason.
- Active commitment details needed to explain conflicts.
- Role-specific scope and action options.
- Required-reason validation, loading lockout, and friendly API errors.

## Verification Evidence

- API close removes a room type from public search and open restores it.
- Active booking overlap returns HTTP 409 without changing restrictions.
- Receptionist room-type close returns HTTP 403 while physical-room block succeeds.
- Concurrent online booking and physical-room block cannot both commit.
- Partial unblock preserves restrictions before and after the selected dates.
- Domain tests reject missing reasons and persisted `Open` intervals.
- Pixel 7 profile verification confirmed responsive layout and friendly conflict
  handling against the local SQL Server and API.

## Residual Work

- Controlled exception and booking relocation are not implemented.
- Hotel setup status bypass remains in ALN-008.
- Dedicated Application unit tests and broader Mobile widget interaction tests
  remain in ALN-014.
