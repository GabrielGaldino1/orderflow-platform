# ADR-001: Use an orchestrated saga

- **Status:** Accepted
- **Date:** 2026-09-13
- **Owners:** OrderFlow

## Context

Order processing spans inventory reservation, payment, and compensation across independently deployed applications. The workflow must expose a coherent order state while tolerating asynchronous results, duplicates, delays, and partial failures. A distributed transaction is neither available nor desirable.

The main alternatives are choreography, in which each participant reacts to domain events and decides what to do next, and orchestration, in which one component owns the workflow and issues commands.

## Decision

Use an orchestrated saga. The `order-service` owns the order workflow, persists its current state and transition history, consumes inventory and payment results, and emits the next command through its Transactional Outbox.

The workers own their local business capabilities and data. They do not infer the complete order workflow. Commands express requested work; events express results that have already occurred.

No dedicated workflow service or external workflow engine will be introduced for the MVP.

## Consequences

### Positive

- The order lifecycle and compensation policy have a single source of truth.
- State transitions are easier to explain, test, and observe.
- Workers stay decoupled from the overall process and can evolve independently.

### Negative

- The `order-service` carries more coordination logic.
- Its state machine must explicitly handle duplicate, delayed, and incompatible events.
- Adding workflow steps requires changing the orchestrator.

## Alternatives considered

- **Pure choreography:** less central coordination, but makes the end-to-end flow and compensation ownership harder to understand for this project.
- **External workflow engine:** strong operational features, but adds infrastructure and concepts before the project demonstrates the core event-driven design.
- **Distributed transactions:** rejected because they couple services and do not fit Kafka-based asynchronous processing.

## Implementation notes

Every accepted transition must persist the order state, transition history, and resulting command in one local transaction. Invalid business transitions must not mutate state and must follow the DLQ and observability policy.

## Revisit when

The workflow becomes dynamic, long-running beyond the planned scope, or operational recovery requires capabilities that are impractical to implement in the orchestrator.

