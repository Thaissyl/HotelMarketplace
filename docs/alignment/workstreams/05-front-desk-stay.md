# WS-05 Front Desk and Stay Lifecycle

Status: Check-in, assignment, Walk-in, and checkout lifecycles are broadly aligned

## Aligned Evidence

- Hotel booking list, status/date filters, room list, check-in, checkout, and
  Walk-in endpoints exist.
- Check-in and checkout use Serializable transactions and application locks.
- Checkout creates an Invoice and HousekeepingTask and moves rooms to Dirty.
- Concurrent check-in is covered by an integration test.
- Check-in is restricted to the arrival date and requires identity type and number.
- Pre-assignment and room replacement use the same booking, room-type, and room locks.
- No-show enforces hotel access, Confirmed state, a configured UTC operational
  window, assignment release, and transactional audit/notification evidence.

## Verified Gaps

| Requirement | Finding | Gap |
| --- | --- | --- |
| Approved role decision | Platform Administrator can perform all Front Desk operations | GAP-001 |
| UC-015 | Remediated: arrival date and identity evidence are enforced atomically | ALN-008 |
| UC-016 | Invoice and collection do not model complete outstanding-balance rules | GAP-012, GAP-013 |
| UC-017 | Remediated: no-show operation and mobile action are implemented | GAP-007, ALN-005 |
| UC-028 | No-show candidates and room-status overview are incomplete | GAP-027 |
| UC-029 | Remediated: independent pre-assignment/change-room is available | ALN-008 |
| UC-030 | Collection is only a checkout side effect and uses the wrong status type | GAP-012 |
| UC-031 | Remediated: protected anonymous customer, exact cash collection, and assignment-dependent Confirmed or CheckedIn state | GAP-004, ALN-003 |

## Required Design

Make assignment, stay, collection, and invoice states explicit. Check-in must
validate date, booking, identity policy, quantity, room type, overlap, and room
status atomically. Walk-in follows the approved Anonymous Customer behavior.
