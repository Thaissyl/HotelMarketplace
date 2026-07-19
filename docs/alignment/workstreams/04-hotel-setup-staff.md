# WS-04 Hotel Setup and Staff

Status: Owner setup path and Owner/Manager staff lifecycle exist; delegated
Manager property and inventory setup remains partial

## Aligned Evidence

- Owner can register a PendingReview hotel and manage basic profile, room types,
  and physical rooms.
- Platform Administrator approval and rejection with reason are implemented.
- Staff records are hotel scoped in persistence.
- Owner and Manager staff operations support create, attach, role change,
  deactivate, reactivate, audit, notification, and stale-token invalidation.

## Verified Gaps

| Requirement | Finding | Gap |
| --- | --- | --- |
| UC-009 | Mobile Owner registration ends in an empty workspace without hotel onboarding | GAP-022 |
| UC-010/011/012 | Owner-only controller prevents documented Hotel Manager management | GAP-019 |
| UC-026 | Invitation-token delivery is not used because the MVP supports direct create and attach-existing flows | GAP-020 residual |
| ENT-004 | StaffInvitation remains unused by the approved direct attach-existing flow | GAP-020 residual |
| ENT-005 to ENT-012 | Images, amenities, policy, floor, notes, and facilities are incomplete in contracts | GAP-024 |
| BR-ROOM-002 | Setup status changes bypass operational dependency checks | GAP-016 |

## Required Design

Separate ownership-only authority from delegated Manager authority. Owners may
grant permitted hotel roles; Managers may manage operational roles but cannot
grant PropertyOwner or PlatformAdministrator. Staff lifecycle must support
existing accounts, deactivation, reassignment, revocation, and audit.
