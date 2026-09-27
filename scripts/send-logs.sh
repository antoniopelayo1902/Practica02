#!/usr/bin/env bash
#
# send-logs.sh
# Sube todos los batches a s3://<BUCKET>/input/ esperando N segundos entre
# cada uno. Cada objeto nuevo dispara la maquina de estados via EventBridge.
#
# Uso:
#   ./send-logs.sh <segundos_de_espera> [directorio_batches]
#
source "$(dirname "${BASH_SOURCE[0]}")/00-config.sh"

WAIT_SECONDS="${1:-30}"
BATCH_DIR="${2:-${ROOT_DIR}/batches}"

if ! [[ "$WAIT_SECONDS" =~ ^[0-9]+$ ]]; then
  echo "ERROR: el primer argumento debe ser el numero de segundos a esperar." >&2
  exit 1
fi

shopt -s nullglob
batches=( "${BATCH_DIR}"/openssh-*.log )
shopt -u nullglob

if [[ "${#batches[@]}" -eq 0 ]]; then
  echo "ERROR: no hay batches en '${BATCH_DIR}'. Corre primero scripts/split-log.sh" >&2
  exit 1
fi

total="${#batches[@]}"
echo "Subiendo ${total} batches a s3://${BUCKET}/${INPUT_PREFIX} con ${WAIT_SECONDS}s de espera."
echo "(Ctrl+C para detener)"

i=0
for batch in "${batches[@]}"; do
  i=$(( i + 1 ))
  name="$(basename "$batch")"
  echo "[$(date +%H:%M:%S)] [${i}/${total}] ${name} -> s3://${BUCKET}/${INPUT_PREFIX}${name}"
  aws s3 cp "$batch" "s3://${BUCKET}/${INPUT_PREFIX}${name}" --only-show-errors
  if [[ "$i" -lt "$total" ]]; then
    sleep "$WAIT_SECONDS"
  fi
done

echo "Terminado. Revisa Step Functions y las tablas ${LOGS_TABLE} / ${ALERTS_TABLE}."
