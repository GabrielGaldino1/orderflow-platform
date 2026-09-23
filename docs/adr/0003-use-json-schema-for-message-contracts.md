# ADR-003: Use JSON Schema for message contracts

- **Status:** Accepted
- **Date:** 2026-09-13
- **Owners:** OrderFlow

## Context

Kafka messages cross Spring Boot and Quarkus boundaries and must be explicit, testable, human-readable, and versionable. The principal candidates were JSON Schema, Apache Avro, and Protocol Buffers.

## Decision

Use JSON payloads validated by JSON Schema Draft 2020-12. Schemas and examples live in `orderflow-contracts`. Every schema uses `additionalProperties: false` at each object boundary and explicitly declares required fields, formats, constraints, and enumerations.

Each message uses the shared envelope defined in the Event Catalog and a message-specific payload schema. Producers and consumers must validate contract compatibility in automated tests. Runtime validation may be added at trust boundaries or diagnostic paths, but compile-time mapping and contract tests remain mandatory.

## Consequences

### Positive

- Contracts are readable without generated binary tooling.
- The same artifacts support documentation, examples, and automated validation.
- Strict schemas detect accidental producer drift early.

### Negative

- JSON payloads are larger than binary formats.
- Java classes are not automatically kept in sync unless generation or tests enforce it.
- Strictness requires deliberate rollout of optional fields.

## Alternatives considered

- **Avro with Schema Registry:** mature Kafka compatibility support and compact messages, but adds infrastructure and generated-type workflow to the MVP.
- **Protocol Buffers:** compact and strongly typed, but less natural for the selected documentation-first contract workflow.
- **Unschematized JSON:** simplest initially, but does not meet the project's reliability and contract-testing goals.

## Implementation notes

Schema identifiers and file paths must be stable. Valid and invalid examples are committed next to schemas. Monetary values use explicit decimal representation and ISO currency codes as defined by the catalog.

## Revisit when

Throughput, payload size, multi-language generation, or centralized compatibility enforcement justifies a binary format or Schema Registry.

