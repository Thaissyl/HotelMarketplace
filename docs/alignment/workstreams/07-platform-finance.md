# WS-07 Platform Administration and Finance

Status: Core dual-collection, reconciliation, and settlement integrity aligned by ALN-007; commission administration UI remains partial

## Aligned Evidence

- PlatformAdminController is globally role protected.
- Hotel approve/reject and commission-rate update are transactional and audited.
- Finance reads use no-tracking projections.
- Settlement and refund entities and admin list/status endpoints exist.
- Customer Pay at Property and Platform Collect demo use distinct collection and
  commission lifecycles.
- Settlement creation and finalization enforce collection-type eligibility,
  refund outcomes, reconciliation evidence, exact amounts, and immutable items.
- Mobile Admin exposes reconciliation and settlement creation/finalization.

## Verified Gaps

| Requirement | Finding | Gap |
| --- | --- | --- |
| UC-019 | Mobile still lacks dedicated commission-rate management | GAP-026 |
| UC-030 | Mobile does not yet expose independent partial collection before checkout | Residual ALN-007 UX |
| ENT-019 to ENT-022 | Service-charge folio detail is not modeled beyond booking amount/refund/balance | GAP-013, GAP-024 |

## Required Design

Finance calculations must be server-derived and immutable per booking snapshot.
Platform Collect settlement requires paid and reconciled demo transaction,
resolved refunds, and an eligible business outcome. Pay-at-Property commission
collection uses collection and receivable evidence, not online reconciliation.
