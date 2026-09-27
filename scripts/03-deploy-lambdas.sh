#!/usr/bin/env bash
#
# 03-deploy-lambdas.sh
# Empaqueta y despliega las 3 Lambdas (crea o actualiza). Usa LabRole.
#   - split-batch : descarga el batch de S3 y lo separa en lineas
#   - get-alerts  : GET /alerts
#   - get-logs    : GET /logs?top=N
#
source "$(dirname "${BASH_SOURCE[0]}")/00-config.sh"

mkdir -p "$DIST_DIR"

package() {
  local src_dir="$1" zip_path="$2"
  rm -f "$zip_path"
  ( cd "$src_dir" && zip -q -r "$zip_path" lambda_function.py )
}

deploy() {
  local name="$1" src_dir="$2" env_vars="$3"
  local zip_path="${DIST_DIR}/${name}.zip"

  package "$src_dir" "$zip_path"
  log "Lambda ${name}"

  if aws lambda get-function --function-name "$name" >/dev/null 2>&1; then
    aws lambda update-function-code --function-name "$name" \
      --zip-file "fileb://${zip_path}" >/dev/null
    aws lambda wait function-updated --function-name "$name"
    aws lambda update-function-configuration --function-name "$name" \
      --environment "Variables={${env_vars}}" --timeout 30 >/dev/null
    aws lambda wait function-updated --function-name "$name"
    echo "    actualizada."
  else
    aws lambda create-function --function-name "$name" \
      --runtime "$LAMBDA_RUNTIME" \
      --role "$ROLE_ARN" \
      --handler lambda_function.lambda_handler \
      --zip-file "fileb://${zip_path}" \
      --timeout 30 --memory-size 256 \
      --environment "Variables={${env_vars}}" >/dev/null
    aws lambda wait function-active-v2 --function-name "$name"
    echo "    creada."
  fi
}

deploy "$SPLIT_LAMBDA"  "${ROOT_DIR}/src/split-batch" "LOGS_TABLE=${LOGS_TABLE}"
deploy "$ALERTS_LAMBDA" "${ROOT_DIR}/src/get-alerts"  "ALERTS_TABLE=${ALERTS_TABLE}"
deploy "$LOGS_LAMBDA"   "${ROOT_DIR}/src/get-logs"    "LOGS_TABLE=${LOGS_TABLE},LOGS_GSI=${LOGS_GSI},LOGS_GSI_PK_VALUE=${LOGS_GSI_PK_VALUE}"

echo "    Lambdas listas."
