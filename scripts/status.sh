#!/usr/bin/env bash
#
# status.sh
# Muestra el estado de todos los recursos. Util para el video (antes y
# despues del teardown).
#
source "$(dirname "${BASH_SOURCE[0]}")/00-config.sh"

check() {  # check <etiqueta> <comando...>
  local label="$1"; shift
  if "$@" >/dev/null 2>&1; then
    printf "  [OK]      %s\n" "$label"
  else
    printf "  [AUSENTE] %s\n" "$label"
  fi
}

echo "Recursos del proyecto ${PROJECT} en ${AWS_REGION}:"
check "S3 bucket ${BUCKET}"                 aws s3api head-bucket --bucket "$BUCKET"
check "DynamoDB ${LOGS_TABLE}"              aws dynamodb describe-table --table-name "$LOGS_TABLE"
check "DynamoDB ${ALERTS_TABLE}"            aws dynamodb describe-table --table-name "$ALERTS_TABLE"
check "Lambda ${SPLIT_LAMBDA}"              aws lambda get-function --function-name "$SPLIT_LAMBDA"
check "Lambda ${ALERTS_LAMBDA}"             aws lambda get-function --function-name "$ALERTS_LAMBDA"
check "Lambda ${LOGS_LAMBDA}"               aws lambda get-function --function-name "$LOGS_LAMBDA"
check "Step Functions ${STATE_MACHINE}"     aws stepfunctions describe-state-machine --state-machine-arn "$STATE_MACHINE_ARN"
check "EventBridge rule ${RULE_NAME}"       aws events describe-rule --name "$RULE_NAME"

API_ID="$(aws apigatewayv2 get-apis --query "Items[?Name=='${API_NAME}'].ApiId | [0]" --output text 2>/dev/null || true)"
if [[ -n "$API_ID" && "$API_ID" != "None" ]]; then
  printf "  [OK]      HTTP API %s (%s)\n" "$API_NAME" "$(aws apigatewayv2 get-api --api-id "$API_ID" --query ApiEndpoint --output text)"
else
  printf "  [AUSENTE] HTTP API %s\n" "$API_NAME"
fi

echo
if aws dynamodb describe-table --table-name "$LOGS_TABLE" >/dev/null 2>&1; then
  echo "Conteo aproximado de items (scan):"
  printf "  %-16s %s\n" "$LOGS_TABLE"   "$(aws dynamodb scan --table-name "$LOGS_TABLE"   --select COUNT --query Count --output text)"
  printf "  %-16s %s\n" "$ALERTS_TABLE" "$(aws dynamodb scan --table-name "$ALERTS_TABLE" --select COUNT --query Count --output text)"
fi
