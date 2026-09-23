# ADR-010: Evolve from mocks to a payment provider simulator

- **Status:** Accepted
- **Date:** 2026-09-13
- **Owners:** OrderFlow

## Context

Payment integration must demonstrate immediate and asynchronous outcomes, timeouts, retries, webhook security, and duplicates. Building a complete provider simulator before the internal contract stabilizes would front-load infrastructure and slow the first vertical slice.

## Decision

Evolve the provider integration in three increments:

1. use deterministic mocks in unit and component tests;
2. at the beginning of Phase 3, exercise the webhook manually with documented signed requests;
3. once the payment and webhook contracts are stable, introduce an automated `orderflow-payment-provider-simulator` component.

The simulator is development infrastructure, not a business microservice. It may have a small control interface protected by Keycloak for selecting scenarios. It must support immediate approval, immediate decline, pending followed by approval or decline, duplicate webhook delivery, invalid signature, timeout, and temporary unavailability.

Opaque test tokens such as `tok_approved` and `tok_pending` choose deterministic behavior; they are never real payment credentials.

## Consequences

### Positive

- Early work remains focused on the first end-to-end behavior.
- Each maturity step adds a demonstrable testing capability.
- The eventual simulator tests a real HTTP boundary and webhook lifecycle.

### Negative

- Manual testing is temporarily required.
- Mocks can diverge from the final simulator if contracts are not shared.
- The simulator adds another repository and runtime component in Phase 3.

## Alternatives considered

- **Build the simulator in Phase 1:** provides realism earlier, but delays domain flow and risks rework.
- **Use only mocks:** simpler, but cannot credibly demonstrate HTTP failure handling and signed callbacks.
- **Use a commercial sandbox:** introduces external availability, credentials, and provider-specific constraints.

## Implementation notes

The simulator and worker share contract artifacts, not implementation code. Scenario controls must never be exposed as production functionality. Manual webhook testing ends as the normal workflow once automated scenarios cover it reliably.

## Revisit when

A real payment sandbox is introduced or simulator maintenance exceeds its portfolio and testing value.

