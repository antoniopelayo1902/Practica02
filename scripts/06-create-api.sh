#!/usr/bin/env bash
#
# 06-create-api.sh
# API Gateway HTTP API con dos rutas, cada una a su propia Lambda:
#   GET /alerts        -> get-alerts
#   GET /logs?top=N    -> get-logs
#
source "$(dirname "${BASH_SOURCE[0]}")/00-config.sh"

log "HTTP API ${API_NAME}"

API_ID="$(aws apigatewayv2 get-apis --query "Items[?Name=='${API_NAME}'].ApiId | [0]" --output text)"
if [[ -z "$API_ID" || "$API_ID" == "None" ]]; then
  API_ID="$(aws apigatewayv2 create-api --name "$API_NAME" --protocol-type HTTP \
    --query ApiId --output text)"
  echo "    API creada: ${API_ID}"
else
  echo "    API ya existe: ${API_ID}"
fi

add_route() {
  local route_key="$1" lambda_name="$2" path="$3"
  local lambda_arn integration_id

  lambda_arn="$(lambda_arn "$lambda_name")"

  integration_id="$(aws apigatewayv2 get-integrations --api-id "$API_ID" \
    --query "Items[?IntegrationUri=='${lambda_arn}'].IntegrationId | [0]" --output text)"
  if [[ -z "$integration_id" || "$integration_id" == "None" ]]; then
    integration_id="$(aws apigatewayv2 create-integration --api-id "$API_ID" \
      --integration-type AWS_PROXY \
      --integration-uri "$lambda_arn" \
      --payload-format-version 2.0 \
      --query IntegrationId --output text)"
  fi

  if [[ "$(aws apigatewayv2 get-routes --api-id "$API_ID" \
        --query "length(Items[?RouteKey=='${route_key}'])" --output text)" == "0" ]]; then
    aws apigatewayv2 create-route --api-id "$API_ID" \
      --route-key "$route_key" \
      --target "integrations/${integration_id}" >/dev/null
  fi

  # Permiso para que API Gateway invoque la Lambda
  aws lambda add-permission --function-name "$lambda_name" \
    --statement-id "apigw-${API_ID}" \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:execute-api:${AWS_REGION}:${ACCOUNT_ID}:${API_ID}/*/GET${path}" \
    >/dev/null 2>&1 || true

  echo "    ${route_key} -> ${lambda_name}"
}

add_route "GET /alerts" "$ALERTS_LAMBDA" "/alerts"
add_route "GET /logs"   "$LOGS_LAMBDA"   "/logs"

# Stage $default con auto-deploy
if [[ "$(aws apigatewayv2 get-stages --api-id "$API_ID" \
      --query "length(Items[?StageName=='\$default'])" --output text)" == "0" ]]; then
  aws apigatewayv2 create-stage --api-id "$API_ID" --stage-name '$default' --auto-deploy >/dev/null
fi

ENDPOINT="$(aws apigatewayv2 get-api --api-id "$API_ID" --query ApiEndpoint --output text)"
mkdir -p "$DIST_DIR"
echo "$ENDPOINT" > "${DIST_DIR}/api-endpoint.txt"

echo
echo "    API lista:"
echo "      ${ENDPOINT}/alerts"
echo "      ${ENDPOINT}/logs?top=5"
