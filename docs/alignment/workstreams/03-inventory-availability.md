# WS-03 Inventory and Availability

Status: Cross-channel commitment and availability management aligned

## Aligned Evidence

- Room number uniqueness and room-type validation are configured.
- Marketplace booking serializes room-type quantity checks.
- Check-in serializes booking and physical-room assignment.
- RoomAvailability and RoomStatusHistory entities exist.
- Marketplace and Walk-in creation share a room-type inventory lock and one
  commitment calculation.
- Overlapping date windows, payment holds, room blocks, and current-day transient
  room states are included in availability decisions.
- Availability calendar reads project room types, physical-room lifecycle status,
  active booking commitments, assignments, and date restrictions without loading
  full booking aggregates.
- Owner and Manager may close/open room-type inventory or block/unblock individual
  rooms. Receptionist access is restricted to physical-room block/unblock.
- Restriction changes use the same room-type and physical-room lock hierarchy as
  booking and assignment, reject active commitment conflicts, write audit evidence,
  and affect public marketplace queries immediately.

## Verified Gaps

| Requirement | Finding | Gap |
| --- | --- | --- |
| UC-031 | Walk-in still uses the staff actor as Customer and always checks in immediately | GAP-004 |
| BR-ROOM-002 | Owner setup changes can force operational rooms back to Available | GAP-016 |

## Required Design

The remaining inventory work belongs to ALN-008: setup mutations must not bypass
the operational room lifecycle, and inspection/release policy must determine when
transient rooms return to sale.
