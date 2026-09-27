#!/usr/bin/env bash
set -euo pipefail

psql --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" --set=ON_ERROR_STOP=1 <<-EOSQL
  CREATE ROLE order_service LOGIN PASSWORD '${ORDER_SERVICE_DB_PASSWORD}';
  CREATE ROLE inventory_worker LOGIN PASSWORD '${INVENTORY_WORKER_DB_PASSWORD}';
  CREATE ROLE payment_worker LOGIN PASSWORD '${PAYMENT_WORKER_DB_PASSWORD}';

  CREATE DATABASE orderflow_orders OWNER order_service;
  CREATE DATABASE orderflow_inventory OWNER inventory_worker;
  CREATE DATABASE orderflow_payments OWNER payment_worker;

  REVOKE CONNECT ON DATABASE orderflow_orders FROM PUBLIC;
  REVOKE CONNECT ON DATABASE orderflow_inventory FROM PUBLIC;
  REVOKE CONNECT ON DATABASE orderflow_payments FROM PUBLIC;

  GRANT CONNECT ON DATABASE orderflow_orders TO order_service;
  GRANT CONNECT ON DATABASE orderflow_inventory TO inventory_worker;
  GRANT CONNECT ON DATABASE orderflow_payments TO payment_worker;
EOSQL
