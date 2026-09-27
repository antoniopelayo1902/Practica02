#!/usr/bin/env bash
#
# teardown.sh
# Elimina TODOS los recursos de la practica:
#   EventBridge rule, Step Functions, API Gateway, Lambdas, tablas DynamoDB y bucket S3.
#
# Uso:
#   ./teardown.sh          # pide confirmacion
#   ./teardown.sh --yes    # sin confirmacion
#
source "$(dirname "${BASH_SOURCE[0]}")/00-config.sh"

if [[ "${1:-}" != "--yes" ]]; then
  echo "ADVERTENCIA: se van a ELIMINAR estos recursos en la cuenta ${ACCOUNT_ID} (${AWS_REGION}):"
  echo "  - S3 bucket        ${BUCKET} (y todo su contenido)"
  echo "  - DynamoDB         ${LOGS_TABLE}, ${ALERTS_TABLE}"
  echo "  - Lambdas          ${SPLIT_LAMBDA}, ${ALERTS_LAMBDA}, ${LOGS_LAMBDA}"
  echo "  - Step Functions   ${STATE_MACHINE}"
  echo "  - EventBridge      ${RULE_NAME}"
  echo "  - HTTP API         ${API_NAME}"
  read -r -p "Escribe 'si' para continuar: " confirm
  [[ "$confirm" == "si" ]] || { echo "Cancelado."; exit 0; }
fi

log "EventBridge rule"
aws events remove-targets --rule "$RULE_NAME" --ids state-machine >/dev/null 2>&1 || true
aws events delete-rule --name "$RULE_NAME" >/dev/null 2>&1 && echo "    eliminada." || echo "    no existia."

log "Step Functions"
aws stepfunctions delete-state-machine --state-machine-arn "$STATE_MACHINE_ARN" >/dev/null 2>&1 \
  && echo "    eliminada." || echo "    no existia."

log "HTTP API"
API_ID="$(aws apigatewayv2 get-apis --query "Items[?Name=='${API_NAME}'].ApiId | [0]" --output text 2>/dev/null || true)"
if [[ -n "$API_ID" && "$API_ID" != "None" ]]; then
  aws apigatewayv2 delete-api --api-id "$API_ID" && echo "    eliminada (${API_ID})."
else
  echo "    no existia."
fi

log "Lambdas"
for fn in "$SPLIT_LAMBDA" "$ALERTS_LAMBDA" "$LOGS_LAMBDA"; do
  aws lambda delete-function --function-name "$fn" >/dev/null 2>&1 \
    && echo "    ${fn} eliminada." || echo "    ${fn} no existia."
done

log "DynamoDB"
for table in "$LOGS_TABLE" "$ALERTS_TABLE"; do
  if aws dynamodb describe-table --table-name "$table" >/dev/null 2>&1; then
    aws dynamodb delete-table --table-name "$table" >/dev/null
    echo "    ${table} eliminandose..."
  else
    echo "    ${table} no existia."
  fi
done
for table in "$LOGS_TABLE" "$ALERTS_TABLE"; do
  aws dynamodb wait table-not-exists --table-name "$table" 2>/dev/null || true
done
echo "    tablas eliminadas."

log "S3"
if aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
  aws s3 rm "s3://${BUCKET}" --recursive >/dev/null
  aws s3api delete-bucket --bucket "$BUCKET"
  echo "    ${BUCKET} eliminado."
else
  echo "    ${BUCKET} no existia."
fi

rm -rf "$DIST_DIR" "${ROOT_DIR}/batches"

echo
echo "Teardown completo. Verifica con: ./scripts/status.sh"
