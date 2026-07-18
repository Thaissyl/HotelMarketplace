# Hotel Marketplace Management System

Hotel Marketplace Management System is a multi-tenant hotel booking and operations platform prepared for a Flutter mobile client and an ASP.NET Core Web API backend.

This repository contains the MVP backend, Flutter mobile client, Docker-based local database setup, integration tests, and development utilities for the Hotel Marketplace Management System.

## Project Purpose

The system is designed for a hotel marketplace where guests can search hotels, customers can create bookings, and hotel staff can operate daily hotel workflows.

The MVP scope includes:

- Public hotel search and hotel detail browsing.
- Customer registration, login, profile management, booking, payment, cancellation, and refund status tracking.
- Property owner and hotel manager hotel setup.
- Room type, physical room, and availability management.
- Hotel-scoped staff management.
- Front desk operations such as arrivals, room assignment, check-in, checkout, no-show, pay-at-property collection, and walk-in booking.
- Housekeeping task management.
- Maintenance request management.
- Platform administration for hotel approval, commission, payment reconciliation, refund status, settlement, and dashboard reporting.

## Main User Roles

- Guest
- Customer
- Property Owner
- Hotel Manager
- Receptionist
- Housekeeping Staff
- Maintenance Staff
- Platform Administrator

External systems:

- payOS Payment Gateway
- Notification Service or mock notification recorder
- System Scheduler

## Technology Stack

| Area | Technology |
| --- | --- |
| Mobile app | Flutter |
| Backend API | ASP.NET Core Web API |
| Backend language | C# |
| Backend architecture | Clean Architecture |
| Database | Microsoft SQL Server |
| ORM | Entity Framework Core |
| Payment provider | payOS |
| Local infrastructure | Docker Compose |
| Testing | xUnit, FluentAssertions, ASP.NET Core integration testing |

## Repository Structure

```text
HotelMarketplace/
  backend/
    src/
      Presentation.Api/
      Application/
      Domain/
      Infrastructure.Persistence/
      Infrastructure.Payment/
      Infrastructure.Notification/
      Infrastructure.Scheduling/
      SharedKernel/
    tests/
      Domain.UnitTests/
      Application.UnitTests/
      Api.IntegrationTests/
  mobile/
    lib/
      app/
      core/
      features/
      shared/
    assets/
      icons/
      images/
    test/
  docs/
    api/
    database/
    design/
    requirements/
  infra/
    docker/
    sqlserver/
      init/
  scripts/
```

## Backend Project Layout

The backend follows Clean Architecture boundaries.

| Project | Responsibility |
| --- | --- |
| `Presentation.Api` | HTTP API surface, authentication filters, OpenAPI configuration, request/response contracts. |
| `Application` | Use case orchestration, DTOs, validators, authorization checks, transaction boundaries. |
| `Domain` | Domain entities, value objects, enums, and business rules. |
| `Infrastructure.Persistence` | SQL Server persistence, EF Core configuration, migrations, repository implementations. |
| `Infrastructure.Payment` | payOS client and payment webhook verification. |
| `Infrastructure.Notification` | Notification dispatcher and provider adapters. |
| `Infrastructure.Scheduling` | Background jobs such as unpaid booking expiration. |
| `SharedKernel` | Shared primitives such as common results, exceptions, constants, and time abstractions. |

Dependency direction should stay inward:

```text
Presentation.Api
  -> Application
  -> Domain
  -> SharedKernel

Infrastructure.*
  -> Application
  -> Domain
  -> SharedKernel
```

`Domain` must not depend on infrastructure, API, database, payment, or UI concerns.

## Mobile Project Layout

The Flutter app is prepared with a feature-oriented structure.

| Folder | Responsibility |
| --- | --- |
| `lib/app` | App-level routing, theme, bootstrap, dependency registration. |
| `lib/core` | Shared technical utilities such as API client, storage, constants, error handling. |
| `lib/features` | Feature modules such as auth, marketplace, booking, hotel setup, staff, front desk, housekeeping, maintenance, finance. |
| `lib/shared` | Shared widgets, formatters, UI helpers, reusable models. |
| `assets/images` | Image assets. |
| `assets/icons` | Icon assets. |
| `test` | Flutter tests. |

## Prerequisites

Install these tools before working on the project:

- Git
- Docker Desktop
- .NET SDK compatible with the repository `global.json`
- Flutter SDK
- A code editor such as Visual Studio, Rider, or VS Code

Current local setup used when this skeleton was created:

- .NET SDK `10.0.103`
- Backend target framework `net8.0`
- Flutter `3.41.9`
- Dart `3.11.5`

Check your local versions:

```powershell
dotnet --version
flutter --version
docker --version
```

## Getting Started

Clone the repository:

```powershell
git clone https://github.com/Thaissyl/HotelMarketplace.git
cd HotelMarketplace
```

Create a local environment file:

```powershell
Copy-Item .env.example .env
```

Update `.env` values if needed. Do not commit `.env`.

## Start Local SQL Server

Start SQL Server with Docker Compose:

```powershell
docker compose up -d sqlserver
```

Check container status:

```powershell
docker compose ps
```

Stop local infrastructure:

```powershell
docker compose down
```

Remove local SQL Server volume if you need a clean database:

```powershell
docker compose down -v
```

## Restore Backend Dependencies

Restore all backend projects through the solution file:

```powershell
dotnet restore backend/HotelMarketplace.slnx
```

Use restore as the first backend validation command before building, running migrations, or executing tests.

## Restore Mobile Dependencies

Restore Flutter dependencies:

```powershell
cd mobile
flutter pub get
cd ..
```

The mobile folder contains the Flutter app bootstrap, routing, auth/session management, marketplace browsing, booking, operations, and platform administration screens.

## Environment Configuration

The root `.env.example` file documents local configuration keys:

```text
ASPNETCORE_ENVIRONMENT
API_HTTP_PORT
API_HTTPS_PORT
SA_PASSWORD
SQLSERVER_PORT
SQLSERVER_DATABASE
SQLSERVER_USER
SQLSERVER_HOST
JWT_ISSUER
JWT_AUDIENCE
JWT_SIGNING_KEY
PAYOS_CLIENT_ID
PAYOS_API_KEY
PAYOS_CHECKSUM_KEY
MOBILE_API_BASE_URL
```

Use `.env` for local values and secrets. Keep `.env.example` safe for placeholder values only.

## Domain Notes

Important business concepts from the requirements:

- The platform is hotel-only and private-room-only for MVP.
- Hotel access is multi-tenant and hotel-scoped.
- Staff roles are assigned per hotel.
- Marketplace availability uses a hybrid model:
  - Public booking checks room type quantity by date.
  - Physical room assignment happens before or during check-in.
- Platform Collect uses payOS.
- Pay at Property is recorded by hotel-side staff.
- Refunds and settlements are manual for MVP.
- Protected financial, staff, booking, room, housekeeping, and maintenance actions should be auditable.

## Recommended Implementation Order

1. Add minimal backend API bootstrap.
2. Add shared primitives and project-level dependency injection placeholders.
3. Implement authentication, roles, and hotel-scoped authorization.
4. Add domain entities and EF Core persistence mappings.
5. Implement marketplace search and hotel detail read flows.
6. Implement customer booking and atomic availability reservation.
7. Add payOS payment callback handling and idempotency.
8. Add unpaid booking expiration scheduling.
9. Implement owner and manager hotel setup.
10. Implement room inventory and availability management.
11. Implement staff management.
12. Implement front desk workflows.
13. Implement housekeeping and maintenance workflows.
14. Implement platform finance and reporting workflows.
15. Add integration tests for critical state transitions.

## Development Rules

- Keep business logic out of `Presentation.Api`.
- Keep infrastructure details out of `Domain`.
- Keep tenant authorization checks explicit for hotel-scoped operations.
- Treat payment callbacks as idempotent.
- Use transactions for booking, payment, check-in, checkout, refund, and settlement state changes.
- Add tests when implementing domain rules or state transitions.
- Do not commit secrets, local `.env` files, generated database files, `bin/`, `obj/`, or Flutter build output.

## Current Repository Status

Implemented:

- ASP.NET Core backend API with Clean Architecture boundaries.
- Domain entities, EF Core persistence, SQL Server migrations, and multi-tenant hotel scoping.
- JWT authentication, role-based authorization, and hotel-scoped policies.
- Marketplace search, booking, expiration, front desk, housekeeping, maintenance, platform admin, finance, refund, and settlement workflows.
- Flutter mobile app with auth, marketplace, booking, operations, and platform admin screens.
- Docker Compose for local SQL Server.
- Integration tests for critical backend flows.
- Local demo data cleanup script.

## Useful Commands

Restore backend:

```powershell
dotnet restore backend/HotelMarketplace.slnx
```

Restore mobile:

```powershell
cd mobile
flutter pub get
cd ..
```

Validate Docker Compose:

```powershell
docker compose config
```

Start SQL Server:

```powershell
docker compose up -d sqlserver
```

Check Git status:

```powershell
git status
```

Reset local demo hotel names after smoke tests:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\reset-local-demo-data.ps1
```

## Source Documents

The original requirement and design documents are included in the repository:

- `srs-final-mvp-semantic-repair.docx`
- `software-design-document.docx`
- `CODING_BRIEF.md`

Use these documents as the source of truth when implementing features.
