# ADR-002: Use independent repositories under one GitHub project

- **Status:** Accepted
- **Date:** 2026-09-13
- **Owners:** OrderFlow

## Context

OrderFlow contains independently deployable applications built with different frameworks. In particular, payment processing and its external integration must remain decoupled from the other systems. A monorepo would simplify atomic changes, while multiple repositories make ownership and deployment boundaries explicit.

## Decision

Use multiple Git repositories grouped under one GitHub organization or project:

- `orderflow-platform` for architecture, local orchestration, shared operational documentation, and environment configuration;
- `orderflow-contracts` for JSON Schemas, examples, and the Event Catalog;
- `orderflow-order-service`;
- `orderflow-inventory-worker`;
- `orderflow-payment-worker`;
- `orderflow-payment-provider-simulator`, introduced when the simulator is automated.

Applications must not share compiled domain libraries. Cross-repository integration happens through versioned HTTP or event contracts. The contracts repository may publish tagged releases consumed by each application.

## Consequences

### Positive

- Service and deployment boundaries are visible in the portfolio.
- The payment integration can evolve and release independently.
- Each repository can have focused documentation and pipelines.

### Negative

- Cross-repository changes require coordinated releases.
- Local setup and dependency versions need a central manifest or documentation.
- More repositories create additional maintenance overhead for one developer.

## Alternatives considered

- **Monorepo:** easier refactoring and unified tooling, but weakens the deliberate separation requested for the payment component.
- **One repository per source module plus shared code repository:** rejected because shared domain code would couple applications at compile time.

## Implementation notes

The platform repository documents compatible component and contract versions. Repository names, default branches, license, contribution conventions, and release tags should be consistent.

## Revisit when

Repository coordination costs dominate development time or the applications are no longer independently releasable.

