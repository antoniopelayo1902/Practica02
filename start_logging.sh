#!/usr/bin/env bash
#
# start_logging.sh
# Simula el envio de logs: descarga el log de ejemplo (loghub OpenSSH) si no
# existe, lo parte en batches de ~1KB y sube cada batch a S3 esperando N
# segundos entre cada uno.
#
# Uso:
#   ./start_logging.sh 30            # 30 segundos entre batches (default)
#   ./start_logging.sh 30 512        # batches de ~512 bytes
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WAIT_SECONDS="${1:-30}"
MAX_BYTES="${2:-1024}"
MIN_WAIT_SECONDS=30

# Valida antes de descargar y partir el log (la practica pide >= 30 s).
if ! [[ "$WAIT_SECONDS" =~ ^[0-9]+$ ]] || (( WAIT_SECONDS < MIN_WAIT_SECONDS )); then
  echo "ERROR: la espera entre batches debe ser un entero >= ${MIN_WAIT_SECONDS} segundos (recibido: '${WAIT_SECONDS}')." >&2
  echo "Uso: ./start_logging.sh 30 [bytes_por_batch]" >&2
  exit 1
fi

SOURCE_LOG="${ROOT_DIR}/OpenSSH_2k.log"
BATCH_DIR="${ROOT_DIR}/batches"
LOG_URL="https://raw.githubusercontent.com/logpai/loghub/master/OpenSSH/OpenSSH_2k.log"

if [[ ! -f "$SOURCE_LOG" ]]; then
  echo "Descargando log de ejemplo (loghub OpenSSH)..."
  curl -sSL -o "$SOURCE_LOG" "$LOG_URL"
fi

# Batches nuevos en cada corrida (nombres con timestamp -> keys nuevas en S3)
rm -rf "$BATCH_DIR"
"${ROOT_DIR}/scripts/split-log.sh" "$SOURCE_LOG" "$BATCH_DIR" "$MAX_BYTES"

exec "${ROOT_DIR}/scripts/send-logs.sh" "$WAIT_SECONDS" "$BATCH_DIR"
