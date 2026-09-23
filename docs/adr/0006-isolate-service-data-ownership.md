# ADR-006: Isolate service data ownership

- **Status:** Proposed
- **Date:** 2026-09-13
- **Owners:** OrderFlow

## Context

The three applications require durable local state. Local development should remain affordable and simple, but a shared database model would allow accidental joins, foreign keys, or writes across service boundaries and undermine independent evolution.

## Proposed decision

Each application owns a private PostgreSQL database and private credentials. For local development, the databases may run in one PostgreSQL server container:

- `orderflow_orders`, owned by `order-service`;
- `orderflow_inventory`, owned by `inventory-worker`;
- `orderflow_payments`, owned by `payment-worker`.

No application may query, join, reference, migrate, or write another application's database. Cross-service information flows only through published contracts. Each repository owns its migrations.

A separate database is preferred over schemas in one database because credentials and connection boundaries more closely represent production isolation without requiring three local server containers.

## Consequences

### Positive

- Data ownership is enforceable through credentials.
- Local infrastructure remains lighter than one PostgreSQL server per application.
- Future physical separation does not change application semantics.

### Negative

- Cross-service reporting cannot rely on joins.
- Bootstrap scripts must create several databases and roles.
- One local server remains a shared failure domain.

## Alternatives considered

- **One database with separate schemas:** slightly simpler provisioning, but makes cross-schema access easier and isolation weaker.
- **One PostgreSQL server per service:** strongest local resemblance to independent deployment, but costs more resources and configuration.
- **Shared tables:** rejected because they couple releases and ownership.

## Validation required

During Phase 1, verify that Docker Compose can provision isolated databases and credentials repeatably and that each service's migration tooling can access only its own database.

## Revisit when

The local environment becomes too resource-heavy, cloud hosting imposes different isolation constraints, or reporting requirements justify a separate read model.

