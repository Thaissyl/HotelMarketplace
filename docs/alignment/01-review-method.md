# Review Method

## Review Unit

Each review unit is one identifiable requirement, use case, business rule,
status transition, authorization rule, entity invariant, external interaction,
screen behavior, or non-functional constraint.

## Evidence Required

Each conclusion must reference:

- Requirement evidence: document and requirement, use-case, rule, state, entity,
  or screen identifier.
- Design evidence: relevant SDD section, transaction strategy, component, table,
  or sequence description.
- Implementation evidence: concrete backend, database, mobile, configuration, or
  test file and line.
- Runtime evidence when static inspection is insufficient.

## Status Values

| Status | Meaning |
| --- | --- |
| Aligned | Required behavior and safeguards are implemented and verified |
| Partial | Main path exists but required branches, data, roles, or tests are missing |
| Deviated | Implemented behavior conflicts with the approved requirement or design |
| Missing | No implementation evidence exists |
| Document conflict | Authoritative sources disagree and require a decision |
| Out of scope | Explicitly excluded by the canonical SRS |
| Not verified | Evidence has not yet been inspected |

## Severity Values

| Severity | Meaning |
| --- | --- |
| Critical | Security boundary, financial integrity, tenant isolation, or inventory integrity can fail |
| High | Core use case or lifecycle is incorrect or unavailable |
| Medium | Required supporting behavior, role operation, data, or user experience is incomplete |
| Low | Maintainability, documentation, consistency, or minor usability mismatch |

## Review Sequence

1. Extract actors, feature IDs, use cases, business rules, status lifecycles,
   entities, messages, and non-functional requirements from the SRS.
2. Map each item to the intended SDD realization.
3. Inspect backend API, application, domain, persistence, migrations, jobs, and
   integration tests.
4. Inspect mobile routes, guards, repositories, state, screens, validation, and
   role workspaces.
5. Verify previously reported deviations independently.
6. Record gaps, decisions, dependencies, migrations, and test requirements.
7. Produce a sequenced remediation roadmap.
