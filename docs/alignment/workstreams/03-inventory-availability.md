# WS-03 Inventory and Availability

Status: Cross-channel commitment aligned; availability-management APIs remain incomplete

## Aligned Evidence

- Room number uniqueness and room-type validation are configured.
- Marketplace booking serializes room-type quantity checks.
- Check-in serializes booking and physical-room assignment.
- RoomAvailability and RoomStatusHistory entities exist.
- Marketplace and Walk-in creation share a room-type inventory lock and one
  commitment calculation.
- Overlapping date windows, payment holds, room blocks, and current-day transient
  room states are included in availability decisions.

## Verified Gaps

| Requirement | Finding | Gap |
| --- | --- | --- |
| UC-031 | Walk-in still uses the staff actor as Customer and always checks in immediately | GAP-004 |
| UC-013 | Availability block entity has no command/query API and is ignored by public availability | GAP-008 |
| BR-ROOM-002 | Current-day saleability can count Dirty, Cleaning, or InspectionRequired rooms | GAP-008 |
| BR-ROOM-002 | Owner setup changes can force operational rooms back to Available | GAP-016 |

## Required Design

Use one inventory commitment service and lock hierarchy: room-type/date commitment
first, selected physical rooms second. Availability calculation must include
active bookings, payment holds, date blocks, physical-room assignment overlap,
and operationally unsellable states according to current versus future dates.
