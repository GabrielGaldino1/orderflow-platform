# ADR-011: Use the Grafana observability stack

- **Status:** Accepted
- **Date:** 2026-09-13
- **Owners:** OrderFlow

## Context

The portfolio must demonstrate operation of an asynchronous distributed workflow, including correlation, latency, backlogs, retries, DLQs, and business outcomes. Observability should grow incrementally and remain runnable through Docker Compose.

## Decision

Use Grafana as the common visualization interface and build the local stack incrementally:

- Prometheus for metrics;
- Loki for structured logs;
- Tempo for distributed traces;
- Grafana for dashboards and cross-signal navigation.

OpenTelemetry-compatible instrumentation is preferred where practical. Every HTTP request and Kafka message carries or derives correlation context. `orderId` is a searchable business correlation field, while trace and span IDs provide technical causality.

Phase 1 starts with health checks and essential metrics. Structured logs and correlation are required with each vertical feature. Full dashboards and tracing are completed in Phase 5 rather than blocking the first business flow.

## Consequences

### Positive

- One interface demonstrates logs, metrics, and traces.
- The stack is recognizable, locally runnable, and portfolio-friendly.
- Incremental adoption limits early infrastructure work.

### Negative

- The full stack consumes significant local resources.
- Configuration and instrumentation span all repositories.
- High-cardinality labels can damage metric performance.

## Alternatives considered

- **Only application logs:** low setup cost but insufficient for backlog, latency, and cross-service diagnosis.
- **Jaeger plus separate log tooling:** viable, but the selected stack gives a more cohesive local experience.
- **Hosted observability:** operationally capable, but creates cost, accounts, and external dependencies.

## Implementation notes

Do not use `orderId`, `paymentId`, `reservationId`, customer ID, or correlation ID as Prometheus labels. Keep them in logs and traces. Metrics use bounded dimensions such as service, outcome, reason code, message type, and topic. Sensitive payloads and tokens must never be logged.

## Revisit when

The hosting target provides a managed observability platform or local resource consumption prevents a practical developer experience.

