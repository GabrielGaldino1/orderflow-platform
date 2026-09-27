# OrderFlow Platform

Local orchestration, architecture records, and operational documentation for OrderFlow.

## Repository map

The five sibling directories under `Desktop/orderflow` are independent Git repositories:

- `orderflow-platform`: Docker Compose, bootstrap assets, ADRs, and local operations.
- `orderflow-contracts`: Event Catalog, JSON Schemas, examples, and contract validation.
- `orderflow-order-service`: Spring Boot public API and saga orchestrator.
- `orderflow-inventory-worker`: Quarkus inventory worker.
- `orderflow-payment-worker`: Quarkus payment worker.

## F02 environment

The local stack contains:

- PostgreSQL with one server and three databases, owners, and credentials;
- Kafka in KRaft mode with the four v1 topics from the Event Catalog;
- Keycloak with the versioned `orderflow` development realm;
- the three independently built applications and their health endpoints.

Development credentials are intentionally local-only. They may be overridden in an ignored `.env` copied from `.env.example`. Do not reuse them outside local development.

## Prerequisites

- JDK 17 available through `JAVA_HOME` and `PATH`;
- Docker Desktop or another Docker-compatible runtime with Compose v2;
- PowerShell 7 or Windows PowerShell 5.1.

Verify Java before building:

```powershell
java -version
./orderflow-order-service/mvnw.cmd -version
```

Both commands must report Java 17 or newer.

## Build and tests

From `orderflow-platform`:

```powershell
./scripts/build.ps1
```

This runs `clean verify` independently in the three application repositories. The order-service verification includes a PostgreSQL Testcontainers migration test and therefore requires Docker.

Validate the versioned contracts separately:

```powershell
cd ../orderflow-contracts
python -m pip install -r requirements-dev.txt
python scripts/validate_contracts.py
```

## Start and validate

```powershell
Copy-Item .env.example .env
./scripts/start.ps1
```

The script packages each application, starts the complete Compose project, waits for the HTTP checks, and verifies the Kafka topics, Flyway migrations, and cross-database access isolation.

Local endpoints:

| Component | Endpoint |
|---|---|
| order-service liveness | `http://localhost:8080/actuator/health/liveness` |
| order-service readiness | `http://localhost:8080/actuator/health/readiness` |
| inventory-worker liveness | `http://localhost:8081/q/health/live` |
| inventory-worker readiness | `http://localhost:8081/q/health/ready` |
| payment-worker liveness | `http://localhost:8082/q/health/live` |
| payment-worker readiness | `http://localhost:8082/q/health/ready` |
| Keycloak | `http://localhost:8083/realms/orderflow` |

## Stop and restart

Preserve local data:

```powershell
./scripts/stop.ps1
./scripts/start.ps1
```

Exercise a clean bootstrap, including database and realm initialization:

```powershell
./scripts/stop.ps1 -PurgeVolumes
./scripts/start.ps1
```

Removing volumes deletes all local OrderFlow data. It does not modify source repositories.

See [local troubleshooting](docs/local-development.md) for diagnostics and recovery.
