#!/usr/bin/env bash
#
# 01-create-s3-bucket.sh
# Crea el bucket, el prefijo input/ y activa las notificaciones a EventBridge
# (necesarias para que cada objeto nuevo dispare la maquina de estados).
#
source "$(dirname "${BASH_SOURCE[0]}")/00-config.sh"

log "Bucket: ${BUCKET} (${AWS_REGION})"

if aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
  echo "    ya existe, continuo."
else
  if [[ "$AWS_REGION" == "us-east-1" ]]; then
    aws s3api create-bucket --bucket "$BUCKET" --region "$AWS_REGION" >/dev/null
  else
    aws s3api create-bucket --bucket "$BUCKET" --region "$AWS_REGION" \
      --create-bucket-configuration LocationConstraint="$AWS_REGION" >/dev/null
  fi
  echo "    creado."
fi

aws s3api put-object --bucket "$BUCKET" --key "$INPUT_PREFIX" >/dev/null

log "Activando notificaciones S3 -> EventBridge"
aws s3api put-bucket-notification-configuration \
  --bucket "$BUCKET" \
  --notification-configuration '{"EventBridgeConfiguration": {}}'

echo "    s3://${BUCKET}/${INPUT_PREFIX} listo."
