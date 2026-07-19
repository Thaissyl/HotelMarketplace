# WS-04 Hotel Setup and Staff

Status: Owner happy path exists; Manager and staff lifecycle are partial

## Aligned Evidence

- Owner can register a PendingReview hotel and manage basic profile, room types,
  and physical rooms.
- Platform Administrator approval and rejection with reason are implemented.
- Staff records are hotel scoped in persistence.

## Verified Gaps

| Requirement | Finding | Gap |
| --- | --- | --- |
| UC-009 | Mobile Owner registration ends in an empty workspace without hotel onboarding | GAP-022 |
| UC-010/011/012 | Owner-only controller prevents documented Hotel Manager management | GAP-019 |
| UC-026/027 | Staff supports create/list only and creates a new account with one role | GAP-020 |
| ENT-004 | StaffInvitation exists but no onboarding use case uses it | GAP-020 |
| ENT-005 to ENT-012 | Images, amenities, policy, floor, notes, and facilities are incomplete in contracts | GAP-024 |
| BR-ROOM-002 | Setup status changes bypass operational dependency checks | GAP-016 |

## Required Design

Separate ownership-only authority from delegated Manager authority. Owners may
grant permitted hotel roles; Managers may manage operational roles but cannot
grant PropertyOwner or PlatformAdministrator. Staff lifecycle must support
existing accounts, deactivation, reassignment, revocation, and audit.
