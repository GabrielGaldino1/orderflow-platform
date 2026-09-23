# ADR-013: Use strict, versioned contract evolution

- **Status:** Accepted
- **Date:** 2026-09-13
- **Owners:** OrderFlow

## Context

Independent repositories cannot be upgraded atomically. At the same time, schemas use `additionalProperties: false`, so a producer adding an unknown field can break an older consumer even when the field is conceptually optional.

## Decision

Use semantic releases for the contracts repository and explicit schema versions in message envelopes.

Compatible evolution follows an expand-first rollout:

1. update schemas and consumers so they understand the new optional field;
2. deploy all affected consumers;
3. update producers to emit the field.

An optional field may remain within v1 only under this coordinated rollout. Any incompatible change—removing or renaming a field, changing meaning or type, tightening accepted values in a breaking way, or altering required behavior—creates a v2 contract. v1 and v2 coexist for a documented migration window when necessary.

Contract tests validate producers and consumers against tagged contract artifacts. Examples and the Event Catalog change with the schema.

## Consequences

### Positive

- Strict schemas catch drift instead of silently accepting it.
- Breaking changes are visible and migration can be planned.
- Repository releases provide reproducible contract dependencies.

### Negative

- Even optional additions require deployment coordination.
- Multiple versions may need temporary support.
- Compatibility automation and release discipline are required.

## Alternatives considered

- **Allow undeclared properties:** simplifies additive evolution but hides accidental fields and weakens validation.
- **Create v2 for every added field:** safest isolation, but produces unnecessary version proliferation.
- **Update all repositories from a branch or mutable schema:** rejected because builds would not be reproducible.

## Implementation notes

Schemas must have stable identifiers. CI should fail on invalid examples, unexpected producer output, and unreviewed incompatible changes. A changelog records consumer migration requirements.

## Revisit when

A Schema Registry or a different serialization format supplies automated compatibility guarantees that warrant changing the rollout process.

