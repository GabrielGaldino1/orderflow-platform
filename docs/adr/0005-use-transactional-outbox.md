# ADR-005: Use Transactional Outbox from the first event

- **Status:** Accepted
- **Date:** 2026-09-13
- **Owners:** OrderFlow

## Context

Each application must update PostgreSQL and publish Kafka messages without a distributed transaction. Publishing after committing the database can lose messages; publishing before committing can expose work that is later rolled back.

## Decision

Use the Transactional Outbox pattern in every application from its first produced message. A business state change and its outbox record are committed in the same local database transaction. A background publisher sends pending records to Kafka and marks them as published only after broker acknowledgement.

For the MVP, use scheduled polling rather than Change Data Capture. Publication is at-least-once: consumers must remain idempotent because a crash between broker acknowledgement and the status update can cause a duplicate.

The exact batch size, polling interval, lock timeout, and retention period are runtime configuration. Parallel publishers must claim records safely, preferably with row locking and `SKIP LOCKED` where supported.

## Consequences

### Positive

- Database state and the intent to publish cannot diverge within a successful transaction.
- The mechanism is understandable and testable without extra CDC infrastructure.
- Temporary Kafka outages do not block domain transactions indefinitely.

### Negative

- Delivery is not exactly once and requires idempotent consumers.
- Polling adds latency and database load.
- Outbox monitoring, cleanup, and poison-record handling are operational responsibilities.

## Alternatives considered

- **Direct publish around the database transaction:** rejected because it leaves a dual-write failure window.
- **Kafka transactions:** do not atomically include PostgreSQL changes.
- **CDC with Debezium:** robust and scalable, but adds infrastructure and operational complexity before it is needed.

## Implementation notes

Outbox rows should include message ID, aggregate ID, type, schema version, destination, key, serialized payload, creation time, attempt metadata, and publication time. Metrics must cover backlog size, oldest-record age, publish failures, and latency.

## Revisit when

Polling load or latency becomes material, multiple publisher instances are required at scale, or CDC is introduced for broader platform needs.

