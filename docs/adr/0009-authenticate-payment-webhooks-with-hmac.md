# ADR-009: Authenticate payment webhooks with HMAC

- **Status:** Accepted
- **Date:** 2026-09-13
- **Owners:** OrderFlow

## Context

The payment provider sends asynchronous results to a public endpoint. These requests do not carry an end-user token and may be replayed, duplicated, forged, or delivered after a payment reaches a final state.

## Decision

Authenticate each webhook with HMAC-SHA256 over the exact byte sequence:

`timestamp + "." + rawRequestBody`

Use the headers `X-Webhook-Id`, `X-Webhook-Timestamp`, and `X-Webhook-Signature`. Compare signatures in constant time and accept timestamps within five minutes of the receiver's clock. Signature validation must use the raw body before JSON transformation.

Store the provider event ID and a cryptographic payload fingerprint for idempotency:

- invalid signature or stale timestamp: `401`, sanitized audit record, and metric;
- same event ID and identical payload: `200`, with no repeated state change or Kafka event;
- same event ID and different payload: `409`, integrity alert, and no state change;
- valid but conflicting status after a final payment state: `200`, audit and metric, with no state change or Kafka event.

When a valid webhook causes a new payment transition, persist that transition and its internal event in one transaction through the Outbox.

## Consequences

### Positive

- Authenticity, freshness, and replay behavior are explicit and testable.
- Raw provider contracts remain inside `payment-worker`.
- Provider retries receive stable responses without duplicating internal effects.

### Negative

- Clock synchronization and secret management become operational dependencies.
- Raw-body access must be preserved by the HTTP stack.
- Key rotation needs an overlapping-secret strategy later.

## Alternatives considered

- **OIDC Client Credentials for the webhook:** possible but less representative of common provider webhook integrations.
- **HMAC over canonicalized JSON:** risks mismatches caused by serialization differences.
- **IP allowlisting only:** insufficient authentication and awkward in local environments.

## Implementation notes

Never log the signature, secret, payment token, or complete sensitive payload. Document a future rotation procedure that can validate with current and previous secrets during a controlled overlap.

## Revisit when

The external provider requires asymmetric signatures, mutual TLS, or a different canonical signing specification.

