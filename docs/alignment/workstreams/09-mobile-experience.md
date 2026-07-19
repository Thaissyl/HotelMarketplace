# WS-09 Mobile Experience

Status: Demonstrable role workspaces exist; requirement parity and automated coverage are partial

## Aligned Evidence

- Riverpod, GoRouter, Dio, secure storage, centralized errors, and a shared design
  system are established.
- Auth restoration, role landing, hotel selector, Front Desk, housekeeping,
  maintenance, Customer, and Platform Admin workspaces exist.
- Timers and router refresh listeners use disposal hooks.
- UI consolidating several SRS screens into tabs is acceptable where behavior is
  complete.

## Verified Gaps

| Screen/requirement | Finding | Gap |
| --- | --- | --- |
| SCR-004 to SCR-006 | Guest search/detail is redirected to login | GAP-022 |
| SCR-013 | Customer refund status is absent | GAP-011, GAP-027 |
| SCR-015 | New Owner cannot register a hotel | GAP-022 |
| SCR-019 | Availability calendar is absent | GAP-008, GAP-027 |
| SCR-022/023 | No-show candidates and complete room overview are absent | GAP-007, GAP-027 |
| SCR-038/039 | Commission and reconciliation interfaces are absent | GAP-026 |
| NFR-SEC-006 | Main manifest permits cleartext in release | GAP-028 |
| Test implication | One shell widget test does not verify role guards or workflows | GAP-030 |

## Required Design

Preserve the current component system and role dashboard shell. Add missing
behavior incrementally, make public routes genuinely public, keep actions
role-specific, prevent duplicate submissions, use stable pagination/filter state,
and add contract/router/widget tests for each actor's critical flow.
