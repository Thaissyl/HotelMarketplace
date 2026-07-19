# ALN-013 and ALN-014: Durable Features and Requirement Tests

## Scope

This increment closes the remaining durable Customer engagement behavior and
establishes the executable MVP requirement baseline. It also closes the
cross-user task takeover risk identified by GAP-025.

## Durable Customer Engagement

- `SavedHotel` is an account-owned persistence record with a unique
  `(UserAccountId, HotelId)` constraint.
- Only approved and published hotels can be saved.
- Save is idempotent and executes in a Serializable transaction under the SQL
  Server retry execution strategy.
- Notification delivery status remains independent from the new `ReadAtUtc`
  inbox state.
- Notification list and mutation queries always constrain the recipient to the
  authenticated account.
- Mobile performs optimistic saved-hotel and read-state updates, rolls back on
  API failure, and refreshes durable state when the Customer workspace opens.
- Guest marketplace browsing remains public; saving redirects Guests to login
  and is restricted to Customer accounts.

## Operational Ownership

Housekeeping and maintenance status mutations now carry the authenticated actor
and an explicit Manager/Owner override decision into the locked persistence
transaction. A worker may claim an unassigned item or progress their own item,
but cannot overwrite another active assignee. Manager override preserves the
recorded assignee so responsibility history is not silently rewritten.

## Mobile Reporting

Front Desk includes a Rooms workspace that displays all physical rooms and
filters them by live operational status. Counts are derived from the same API
result and refresh with the existing pull-to-refresh workflow.

## Verification

| Verification | Result |
| --- | --- |
| `dotnet test backend/HotelMarketplace.slnx --no-restore` | Passed: 25 Domain, 2 Application, and 40 API integration tests |
| EF Core pending model changes | Passed: model matches migration `AddDurableCustomerEngagement` |
| `flutter analyze` | Passed with no issues |
| `flutter test` | Passed: 14 tests |
| `flutter build apk --debug` | Passed |

The integration suite applies all migrations to a disposable SQL Server
Testcontainer. New tests verify account isolation for saved hotels and
notifications, Customer-only favorite authorization, and assignee ownership
with Manager override. Flutter tests verify engagement contracts, malformed
input rejection, and countdown timer disposal.
