# ADR-004: Organize Kafka topics by domain and message kind

- **Status:** Accepted
- **Date:** 2026-09-13
- **Owners:** OrderFlow

## Context

The system needs stable Kafka destinations without creating one topic for every message type. Commands and events have different semantics and consumers, while ordering must be preserved for operations belonging to the same order.

## Decision

Use one command topic and one domain-event topic per worker domain:

- `orderflow.inventory.commands`;
- `orderflow.inventory.events`;
- `orderflow.payment.commands`;
- `orderflow.payment.events`.

Use `orderId` as the Kafka record key and as the end-to-end correlation identifier. The message envelope carries `messageType` and `schemaVersion`, allowing multiple compatible message types on a topic. Consumer groups are named for the consuming application and responsibility.

Retry and DLQ topics derive from the source topic using documented suffixes and are introduced with the resilience work.

## Consequences

### Positive

- Messages for one order are routed to the same partition within a topic.
- Topic count remains manageable.
- Commands and facts remain semantically distinct.

### Negative

- Ordering is not guaranteed across inventory and payment topics.
- Consumers must route by `messageType` and tolerate unrelated types within their domain topic.
- A hot order could concentrate records in one partition, although this is unlikely for the project scale.

## Alternatives considered

- **Topic per message type:** simple consumer subscriptions but creates operational sprawl.
- **Single topic for all messages:** minimal infrastructure but poor ownership, permissions, and failure isolation.
- **Key by reservation or payment ID:** useful locally, but would weaken order-level ordering and correlation.

## Implementation notes

Partition counts and retention are environment configuration, not contract semantics. Producers must never rely on ordering across different topics. State machines must reject or safely ignore incompatible out-of-order events.

## Revisit when

Domains require different scaling, retention, security policies, or a message type gains materially different operational characteristics.

