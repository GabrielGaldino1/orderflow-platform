# ADR-012: Keep technical failures out of order state

- **Status:** Accepted
- **Date:** 2026-09-13
- **Owners:** OrderFlow

## Context

An asynchronous workflow can be delayed by Kafka outages, provider timeouts, exhausted retries, invalid messages, or internal processing errors. Exposing a generic `PROCESSING_ERROR` order state would mix operational incidents with business outcomes and could incorrectly imply a final customer-visible decision.

## Decision

Order state represents business progress and outcomes only. Technical delivery or processing failures are represented through retry metadata, outbox state, DLQs, logs, metrics, traces, and operational runbooks.

After an ambiguous provider timeout, `payment-worker` retries with the same `paymentId`. If attempts are exhausted, the message is sent to the DLQ and the payment and order remain pending; the system must not convert uncertainty into rejection.

A schema-valid event that is incompatible with the current business state does not mutate the order. It emits a metric and is routed directly to the relevant DLQ. A known business rejection, such as `INSUFFICIENT_STOCK` or a normalized payment decline, does produce the corresponding business transition.

## Consequences

### Positive

- Customer-visible state does not misrepresent infrastructure incidents.
- Business outcomes remain stable and explainable.
- Operational recovery can replay work without undoing an artificial terminal state.

### Negative

- Pending orders may require operator attention.
- Users cannot distinguish a normal wait from an incident using status alone.
- Effective monitoring is mandatory to prevent silent stagnation.

## Alternatives considered

- **Generic `PROCESSING_ERROR` state:** visible but conflates unrelated failures and complicates recovery semantics.
- **Cancel after retries:** provides a terminal state, but can be financially unsafe when the payment result is unknown.
- **Expose detailed technical sub-status:** useful later, but expands the public contract before operational needs are validated.

## Implementation notes

The query API may later expose a coarse, non-sensitive delay indicator without changing the business state machine. Phase 4 defines timeouts, alerts, replay authorization, and reconciliation behavior.

## Revisit when

Product requirements demand explicit customer communication for delayed processing or an operator workflow needs a durable incident state linked to the order.

