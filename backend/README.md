# Backend

ASP.NET Core backend prepared with Clean Architecture project boundaries.

## Projects

- `Presentation.Api`: HTTP API surface, authentication filters, OpenAPI configuration.
- `Application`: use case orchestration, DTOs, validators, authorization checks, transaction boundaries.
- `Domain`: domain entities, value objects, enums, and business rule methods.
- `Infrastructure.Persistence`: SQL Server, EF Core mappings, migrations, repositories.
- `Infrastructure.Payment`: payOS client and webhook verification adapter.
- `Infrastructure.Notification`: notification dispatcher/provider adapters.
- `Infrastructure.Scheduling`: background jobs such as unpaid booking expiration.
- `SharedKernel`: shared result types, exceptions, constants, date/time abstractions.

No business logic has been implemented yet.
