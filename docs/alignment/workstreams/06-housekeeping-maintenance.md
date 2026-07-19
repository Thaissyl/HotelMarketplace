# WS-06 Housekeeping and Maintenance

Status: Basic task execution exists; release lifecycle and assignment controls deviate

## Aligned Evidence

- Checkout creates one housekeeping task per assigned physical room.
- Task and request queries use DTO projections and hotel filtering.
- Maintenance creation blocks a room and state updates use application locks.
- Mobile provides role-oriented lists and primary actions.

## Verified Gaps

| Requirement | Finding | Gap |
| --- | --- | --- |
| Approved role decision | Platform Administrator appears in operational controllers and services | GAP-001 |
| UC-032/033 | Domain enum omits Assigned and IssueReported and task start overwrites assignee | GAP-015, GAP-025 |
| BR-HK-003 | Cleaning completes directly to Available without inspection policy | GAP-015 |
| UC-036 | Maintenance lacks Assigned, OnHold, Completed, diagnosis, work note, and completion result | GAP-015, GAP-024 |
| UC-037 | Resolve immediately releases room to Available | GAP-015 |
| BR-STAFF-005/006 | Same-hotel workers can take over another assignee's work | GAP-025 |
| BR-AUDIT-001 | Operational transitions do not create audit records | GAP-017 |

## Required Design

Separate work completion from room release. Cleaning may require inspection;
maintenance completion may return the room to Dirty/InspectionRequired before
Available. Assignee changes require Manager authority and audit. Staff projections
must exclude unrelated guest and finance data.
