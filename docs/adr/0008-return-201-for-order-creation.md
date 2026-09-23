# ADR-008: Return 201 for order creation

- **Status:** Accepted
- **Date:** 2026-09-13
- **Owners:** OrderFlow

## Context

Creating an order is synchronous as a resource-creation operation, while inventory and payment processing continue asynchronously. The API must communicate both facts accurately.

## Decision

`POST /orders` returns `201 Created` after the order and its first outbox command have been committed in the same transaction. The response includes:

- a `Location` header pointing to `/orders/{orderId}`;
- `orderId`;
- initial status `INVENTORY_PENDING`;
- `createdAt`.

The endpoint requires an `Idempotency-Key`, unique within the authenticated customer scope. An identical retry returns the original result without creating another order. Reuse with a different normalized request is a conflict.

Products are validated against the `order-service` product snapshot before creation. All nonexistent or inactive items are reported together with `422 Unprocessable Content`, and no order or outbox row is created. Repeated product lines are consolidated before totals are calculated and persisted.

## Consequences

### Positive

- HTTP semantics reflect that the order resource already exists.
- Clients receive a stable polling URL and observable initial state.
- Asynchronous downstream processing is not confused with deferred resource creation.

### Negative

- Clients must understand that `201` does not mean the order is confirmed.
- Idempotency records require durable storage and eventual cleanup.
- Validation depends on the order service's product snapshot being maintained.

## Alternatives considered

- **202 Accepted:** appropriate if resource creation itself were deferred, which it is not.
- **200 OK:** does not communicate creation as precisely.
- **Create first and validate asynchronously:** rejected because known invalid products should not enter the workflow.

## Implementation notes

In the MVP, idempotency records do not expire. Cleanup and retention policy are Phase 4 work. A customer querying another customer's order receives `404`; an authorized operator may inspect it.

## Revisit when

Order acceptance itself becomes asynchronous or API consumers require a separate operation resource.

