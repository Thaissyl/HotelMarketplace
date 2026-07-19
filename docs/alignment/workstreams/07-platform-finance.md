# WS-07 Platform Administration and Finance

Status: Approval is aligned; finance lifecycle is partial and sometimes unsafe

## Aligned Evidence

- PlatformAdminController is globally role protected.
- Hotel approve/reject and commission-rate update are transactional and audited.
- Finance reads use no-tracking projections.
- Settlement and refund entities and admin list/status endpoints exist.

## Verified Gaps

| Requirement | Finding | Gap |
| --- | --- | --- |
| UC-019 | Mobile has no commission management client or screen behavior | GAP-026 |
| UC-020 | Reconciliation exception request cannot store the required note | GAP-010, GAP-026 |
| UC-021 | No cancellation path creates RefundRecord; tests seed it directly | GAP-006, GAP-011 |
| UC-022 | Platform Collect eligibility permits Unreconciled and ignores refund outcome/amount | GAP-010 |
| UC-030 | Pay-at-Property commission lifecycle lacks Receivable/Collected/Exception state | GAP-009, GAP-012 |
| ENT-019 to ENT-022 | Invoice, commission, settlement header/item evidence is incomplete | GAP-013, GAP-024 |

## Required Design

Finance calculations must be server-derived and immutable per booking snapshot.
Platform Collect settlement requires paid and reconciled demo transaction,
resolved refunds, and an eligible business outcome. Pay-at-Property commission
collection uses collection and receivable evidence, not online reconciliation.
