# ADR-007: Control concurrent inventory reservations

- **Status:** Proposed
- **Date:** 2026-09-13
- **Owners:** OrderFlow

## Context

Concurrent orders may request the same products. The inventory operation is all-or-nothing and must never oversell. Commands can also be duplicated. The solution must be correct before it is optimized and must avoid deadlocks when an order contains multiple products.

## Proposed decision

Process each reservation in one database transaction and acquire pessimistic write locks for all requested inventory rows in ascending `productId` order. After locking, validate that every item has sufficient available quantity. Either reserve every item and create one `reservationId`, or reject the complete request without changing stock.

Use a unique business constraint for the command identity and retain a normalized fingerprint of `orderId`, products, and quantities. An identical duplicate produces no new effect; a duplicate for the same `orderId` with different content is a permanent integrity conflict, emits a metric, and is routed directly to the DLQ.

## Consequences

### Positive

- The correctness rule is direct and demonstrable under contention.
- Deterministic lock ordering reduces deadlock risk.
- All-or-nothing behavior fits naturally in one transaction.

### Negative

- Contended products serialize reservation work.
- Long transactions or inconsistent lock ordering can reduce throughput.
- Lock timeout and deadlock handling require explicit transient retry policy.

## Alternatives considered

- **Optimistic locking with a version column:** avoids waiting in low contention, but needs retries and becomes noisier for multi-item atomic reservations.
- **Atomic conditional update per item:** efficient for a single item, but rollback and diagnostic behavior are more complex across several items.
- **Kafka partitioning alone:** preserves order-key ordering, not ordering between different orders competing for the same product.

## Validation required

Before acceptance, run Testcontainers integration tests with simultaneous reservations for overlapping multi-item baskets. Prove no overselling, no partial reservation, deterministic duplicate handling, and recovery from lock timeout or deadlock.

## Revisit when

Contention measurements show unacceptable latency or the inventory model is distributed across partitions that cannot share one database transaction.

