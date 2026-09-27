# Local development and troubleshooting

## Diagnostics

Run all commands from `orderflow-platform`.

```powershell
docker compose ps
docker compose logs --tail 100 postgres kafka keycloak order-service inventory-worker payment-worker
./scripts/smoke-test.ps1
```

Application logs must not print database passwords, bearer tokens, authorization headers, or payment tokens.

## Java mismatch

If Maven reports Java 8 or another unsupported runtime, set `JAVA_HOME` to a JDK 17 installation and prepend `%JAVA_HOME%\bin` to `PATH`. Confirm with both `java -version` and `./mvnw.cmd -version` inside each application repository.

## Port conflicts

The foundation uses ports `5432`, `8080`, `8081`, `8082`, `8083`, `9000`, and `9092`. Stop the conflicting local process or override the host-side mapping in a temporary Compose override file; do not edit service-internal ports.

## Database initialization

PostgreSQL initialization scripts execute only when the `postgres-data` volume is empty. After changing local bootstrap credentials or initialization assets, recreate the environment:

```powershell
./scripts/stop.ps1 -PurgeVolumes
./scripts/start.ps1
```

Each service role has `CONNECT` only on its own database. Cross-service joins, migrations, and writes are intentionally unavailable.

## Keycloak realm import

The realm is imported only during a clean Keycloak initialization. If the realm asset changes, purge the local volumes and start again. The seed contains roles and a public development client, but no production secret or real user.

## Kafka topics

Automatic topic creation is disabled. `kafka-init` idempotently provisions exactly the four topics documented by the Event Catalog. Inspect them with:

```powershell
docker compose exec kafka /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:29092 --list
```

## Recovery

Start with a normal restart so data is retained. Purge volumes only when validating a clean bootstrap or recovering disposable local state. If a build fails before Compose starts, run the Maven Wrapper directly in the failing repository to obtain its complete error output.
