#!/usr/bin/env bash
#
# 04-create-state-machine.sh
# Sustituye los placeholders de statemachine/definition.asl.json y crea (o
# actualiza) la maquina de estados en Step Functions.
#
source "$(dirname "${BASH_SOURCE[0]}")/00-config.sh"

TEMPLATE="${ROOT_DIR}/statemachine/definition.asl.json"
RENDERED="${DIST_DIR}/definition.rendered.json"
mkdir -p "$DIST_DIR"

SPLIT_LAMBDA_ARN="$(lambda_arn "$SPLIT_LAMBDA")"

sed \
  -e "s|\${SPLIT_LAMBDA_ARN}|${SPLIT_LAMBDA_ARN}|g" \
  -e "s|\${LOGS_TABLE}|${LOGS_TABLE}|g" \
  -e "s|\${ALERTS_TABLE}|${ALERTS_TABLE}|g" \
  "$TEMPLATE" > "$RENDERED"

log "State machine ${STATE_MACHINE}"

if aws stepfunctions describe-state-machine --state-machine-arn "$STATE_MACHINE_ARN" >/dev/null 2>&1; then
  aws stepfunctions update-state-machine \
    --state-machine-arn "$STATE_MACHINE_ARN" \
    --definition "file://${RENDERED}" \
    --role-arn "$ROLE_ARN" >/dev/null
  echo "    actualizada."
else
  aws stepfunctions create-state-machine \
    --name "$STATE_MACHINE" \
    --type STANDARD \
    --definition "file://${RENDERED}" \
    --role-arn "$ROLE_ARN" >/dev/null
  echo "    creada."
fi

echo "    ${STATE_MACHINE_ARN}"
