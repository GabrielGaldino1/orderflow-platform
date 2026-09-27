#!/usr/bin/env bash
set -euo pipefail

for topic in \
  orderflow-inventory-commands \
  orderflow-inventory-events \
  orderflow-payment-commands \
  orderflow-payment-events
do
  /opt/kafka/bin/kafka-topics.sh \
    --bootstrap-server kafka:29092 \
    --create \
    --if-not-exists \
    --topic "$topic" \
    --partitions 3 \
    --replication-factor 1
done
