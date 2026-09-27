#!/usr/bin/env bash
#
# 05-create-eventbridge-rule.sh
# Regla de EventBridge: cada objeto creado en s3://<bucket>/input/ dispara una
# ejecucion de la maquina de estados.
#
source "$(dirname "${BASH_SOURCE[0]}")/00-config.sh"

log "Regla EventBridge ${RULE_NAME}"

PATTERN=$(cat <<EOF
{
  "source": ["aws.s3"],
  "detail-type": ["Object Created"],
  "detail": {
    "bucket": { "name": ["${BUCKET}"] },
    "object": { "key": [ { "prefix": "${INPUT_PREFIX}" } ] }
  }
}
EOF
)

aws events put-rule \
  --name "$RULE_NAME" \
  --state ENABLED \
  --event-pattern "$PATTERN" >/dev/null

aws events put-targets \
  --rule "$RULE_NAME" \
  --targets "Id=state-machine,Arn=${STATE_MACHINE_ARN},RoleArn=${ROLE_ARN}" >/dev/null

echo "    s3://${BUCKET}/${INPUT_PREFIX}* -> ${STATE_MACHINE}"
