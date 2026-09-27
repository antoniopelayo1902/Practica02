#!/usr/bin/env bash
#
# 02-create-dynamodb.sh
# Crea las tablas Logs y SecurityAlerts.
#
# Logs tiene un GSI (ByArrival) con:
#   - partition key fija  gsi_pk    = "LOG"
#   - sort key            arrived_at = LastModified del batch en S3 (ISO 8601)
# Asi GET /logs?top=N hace Query con Limit=N y ScanIndexForward=false
# en lugar de un Scan.
#
source "$(dirname "${BASH_SOURCE[0]}")/00-config.sh"

create_if_missing() {
  local table="$1"; shift
  if aws dynamodb describe-table --table-name "$table" >/dev/null 2>&1; then
    echo "    tabla ${table} ya existe, continuo."
  else
    aws dynamodb create-table --table-name "$table" "$@" >/dev/null
    echo "    tabla ${table} creada, esperando ACTIVE..."
    aws dynamodb wait table-exists --table-name "$table"
  fi
}

log "Tabla ${LOGS_TABLE} (con GSI ${LOGS_GSI})"
create_if_missing "$LOGS_TABLE" \
  --billing-mode PAY_PER_REQUEST \
  --attribute-definitions \
      AttributeName=id,AttributeType=S \
      AttributeName=gsi_pk,AttributeType=S \
      AttributeName=arrived_at,AttributeType=S \
  --key-schema AttributeName=id,KeyType=HASH \
  --global-secondary-indexes "[
    {
      \"IndexName\": \"${LOGS_GSI}\",
      \"KeySchema\": [
        {\"AttributeName\": \"gsi_pk\", \"KeyType\": \"HASH\"},
        {\"AttributeName\": \"arrived_at\", \"KeyType\": \"RANGE\"}
      ],
      \"Projection\": {\"ProjectionType\": \"ALL\"}
    }
  ]"

log "Tabla ${ALERTS_TABLE}"
create_if_missing "$ALERTS_TABLE" \
  --billing-mode PAY_PER_REQUEST \
  --attribute-definitions AttributeName=id,AttributeType=S \
  --key-schema AttributeName=id,KeyType=HASH

echo "    tablas listas."
