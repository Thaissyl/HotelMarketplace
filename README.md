# Hotel Marketplace Management System

This repository is prepared for a Flutter mobile client and an ASP.NET Core Web API backend using Clean Architecture.

## Folder Structure

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

## Initial Environment

Copy `.env.example` to `.env` for local development values.

Start SQL Server:

```powershell
docker compose up -d sqlserver
```

No business logic has been added in this setup step.
