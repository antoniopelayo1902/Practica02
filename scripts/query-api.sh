#!/usr/bin/env bash
#
# query-api.sh
# Consulta los dos endpoints del API Gateway.
#
# Uso:
#   ./query-api.sh alerts
#   ./query-api.sh logs 5
#
source "$(dirname "${BASH_SOURCE[0]}")/00-config.sh"

API_ID="$(aws apigatewayv2 get-apis --query "Items[?Name=='${API_NAME}'].ApiId | [0]" --output text)"
[[ -n "$API_ID" && "$API_ID" != "None" ]] || { echo "ERROR: no existe el API ${API_NAME}. Corre scripts/06-create-api.sh" >&2; exit 1; }
ENDPOINT="$(aws apigatewayv2 get-api --api-id "$API_ID" --query ApiEndpoint --output text)"

pretty() { if command -v jq >/dev/null; then jq .; elif command -v python3 >/dev/null; then python3 -m json.tool; else cat; fi; }

case "${1:-}" in
  alerts)
    echo "GET ${ENDPOINT}/alerts"
    curl -s "${ENDPOINT}/alerts" | pretty ;;
  logs)
    TOP="${2:-10}"
    echo "GET ${ENDPOINT}/logs?top=${TOP}"
    curl -s "${ENDPOINT}/logs?top=${TOP}" | pretty ;;
  *)
    echo "Uso: $0 alerts | logs [N]" >&2; exit 1 ;;
esac
