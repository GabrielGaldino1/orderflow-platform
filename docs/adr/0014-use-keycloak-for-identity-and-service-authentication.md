# ADR-014: Use Keycloak for identity and service authentication

- **Status:** Accepted
- **Date:** 2026-09-13
- **Owners:** OrderFlow

## Context

The public API requires authenticated customers and operators. Applicable synchronous machine-to-machine calls must not reuse user credentials. Webhooks have a separate provider authentication model.

## Decision

Use Keycloak as the local identity provider.

- Human users authenticate with OpenID Connect. The `order-service` validates access tokens as an OAuth 2.0 resource server.
- Use roles `CUSTOMER` and `OPERATOR`. A customer may create and view only their own orders; attempts to view another customer's order return `404` to avoid disclosing existence. An operator may view all orders for support and demonstration scenarios.
- Applicable service-to-service HTTP integrations use OAuth 2.0 Client Credentials with a distinct confidential client and least-privilege roles.
- The provider simulator's administrative scenario controls require Keycloak authentication.
- Payment webhooks do not use Keycloak; they follow ADR-009's HMAC protocol.

User identity is taken from the stable token subject, not from a client-supplied customer ID. Kafka message authorization is an infrastructure concern and does not propagate end-user bearer tokens in event payloads.

## Consequences

### Positive

- Identity, token issuance, roles, and machine clients are externalized from business code.
- The project demonstrates both OIDC user authentication and Client Credentials.
- Authorization behavior is explicit and testable.

### Negative

- Keycloak adds local infrastructure and realm configuration.
- Realm exports and secrets require disciplined environment handling.
- Role checks across frameworks must remain behaviorally consistent.

## Alternatives considered

- **Custom user and token implementation:** rejected because it adds security risk and distracts from the domain.
- **One shared machine client:** simpler, but weakens least privilege and auditability.
- **Forward user tokens between services:** couples internal processing to user sessions and is unsuitable for asynchronous work.

## Implementation notes

Version a development realm export without real secrets. Tests cover missing, expired, malformed, wrong-audience, and insufficient-role tokens. Logs must not contain access tokens or authorization headers.

## Revisit when

The hosting environment mandates another identity provider, tenant isolation is introduced, or Kafka requires centralized OAuth-based broker authentication.

