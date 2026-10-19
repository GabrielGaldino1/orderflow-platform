# Transactional outbox runbook

The three applications publish durable intents from their own PostgreSQL database. Business changes
and the outbox row are committed in one local transaction. A scheduled publisher claims a bounded
batch, waits for Kafka acknowledgement, and then fills `published_at`.

Delivery is **at least once**. If the process stops after Kafka acknowledges a message but before
PostgreSQL records `published_at`, the claim expires and the same message is sent again. Consumers
must deduplicate by the contract message ID and apply their domain change idempotently.

## Configuration

| Variable | Local default | Purpose |
| --- | ---: | --- |
| `OUTBOX_BATCH_SIZE` | `50` | Maximum rows claimed by one poll. |
| `OUTBOX_POLL_INTERVAL` | `500ms` for order, `1s` for workers | Delay between polls. |
| `OUTBOX_CLAIM_TIMEOUT` | `30s` | Age after which an unfinished claim can be retried. |
| `OUTBOX_SEND_TIMEOUT` | `10s` | Maximum wait for the Kafka acknowledgement. |

`OUTBOX_CLAIM_TIMEOUT` must be greater than `OUTBOX_SEND_TIMEOUT`. While a batch is being
processed, the publisher renews its outstanding claims before each send so later records cannot be
reclaimed merely because earlier Kafka acknowledgements were slow. After a process stops, renewal
also stops and the normal claim timeout makes those records eligible again.

## Metrics

Spring Boot exposes metrics below `/actuator/metrics`; Quarkus exposes Prometheus output at
`/q/metrics`. The order-service metrics endpoint requires an authenticated `OPERATOR` token.

| Metric | Meaning |
| --- | --- |
| `orderflow.outbox.backlog.size` | Unpublished rows. |
| `orderflow.outbox.oldest.age.seconds` | Age of the oldest unpublished row. |
| `orderflow.outbox.publish.attempts` | Kafka send attempts by destination and message type. |
| `orderflow.outbox.publish.failures` | Failed attempts by destination and message type. |
| `orderflow.outbox.publish.latency` | Time from row creation through acknowledged publication. |

Alert on a backlog or oldest age that keeps increasing, or on a sustained increase in failures.
Destination and message type are bounded labels defined by the Event Catalog; message IDs and order
IDs are never metric labels.

## Diagnose a backlog

Inspect application and broker health first:

```powershell
docker compose ps
docker compose logs --tail 100 kafka order-service inventory-worker payment-worker
```

Then query the service-owned database with its own role. For example:

```powershell
docker compose exec postgres psql --username order_service --dbname orderflow_orders --command "SELECT message_id, event_type, destination, created_at, attempt_count, claimed_at, last_error FROM outbox_messages WHERE published_at IS NULL ORDER BY created_at LIMIT 50;"
```

Use `inventory_worker` with `orderflow_inventory` or `payment_worker` with `orderflow_payments` for
the corresponding worker. Do not copy payloads into tickets, logs, or dead-letter context.

## Recover

1. Restore Kafka connectivity and confirm the destination topics exist.
2. Leave pending rows unchanged. The publisher retries failed sends immediately and reclaims stale
   in-flight rows after `OUTBOX_CLAIM_TIMEOUT`.
3. Confirm backlog size and oldest age return to zero and `published_at` is populated.
4. Expect possible duplicates after a crash-window recovery; verify consumer idempotency rather than
   deleting or manually marking rows.

Do not update `published_at`, reset `attempt_count`, delete rows, or replay payloads manually during
normal recovery. Manual data repair requires a separate, reviewed incident procedure.
