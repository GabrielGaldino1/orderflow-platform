# OrderFlow Architecture Decision Records

This directory contains the Architecture Decision Records (ADRs) for OrderFlow. An ADR records one consequential architectural decision, its context, alternatives, and consequences.

## Status model

- **Proposed:** recommended direction that still requires validation or explicit acceptance.
- **Accepted:** current decision that implementations must follow.
- **Superseded:** replaced by a newer ADR; the replacement must be linked.
- **Deprecated:** retained for history but no longer applicable.

Accepted ADRs are immutable. A material change is recorded in a new ADR that supersedes the old one. Minor corrections that do not change the decision may be committed directly.

## Index

| ADR | Decision | Status |
|---|---|---|
| [ADR-001](0001-use-an-orchestrated-saga.md) | Use an orchestrated saga | Accepted |
| [ADR-002](0002-use-independent-repositories.md) | Use independent repositories under one GitHub project | Accepted |
| [ADR-003](0003-use-json-schema-for-message-contracts.md) | Use JSON Schema for message contracts | Accepted |
| [ADR-004](0004-organize-kafka-topics-by-domain-and-message-kind.md) | Organize Kafka topics by domain and message kind | Accepted |
| [ADR-005](0005-use-transactional-outbox.md) | Use Transactional Outbox from the first event | Accepted |
| [ADR-006](0006-isolate-service-data-ownership.md) | Isolate service data ownership | Proposed |
| [ADR-007](0007-control-concurrent-inventory-reservations.md) | Control concurrent inventory reservations | Proposed |
| [ADR-008](0008-return-201-for-order-creation.md) | Return 201 for order creation | Accepted |
| [ADR-009](0009-authenticate-payment-webhooks-with-hmac.md) | Authenticate payment webhooks with HMAC | Accepted |
| [ADR-010](0010-evolve-from-mocks-to-payment-provider-simulator.md) | Evolve from mocks to a provider simulator | Accepted |
| [ADR-011](0011-use-grafana-observability-stack.md) | Use the Grafana observability stack | Accepted |
| [ADR-012](0012-keep-technical-failures-out-of-order-state.md) | Keep technical failures out of order state | Accepted |
| [ADR-013](0013-use-strict-versioned-contract-evolution.md) | Use strict, versioned contract evolution | Accepted |
| [ADR-014](0014-use-keycloak-for-identity-and-service-authentication.md) | Use Keycloak for identity and service authentication | Accepted |

## Proposed decisions to validate

ADR-006 and ADR-007 must be resolved before their affected persistence and inventory functionality is considered complete. ADR-005 is accepted at the architectural level; its polling parameters remain implementation configuration and should be tuned with measurements.

