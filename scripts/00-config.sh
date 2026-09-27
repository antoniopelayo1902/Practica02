#!/usr/bin/env bash
#
# 00-config.sh
# Variables compartidas por todos los scripts. Se hace "source" desde cada uno.
# Todo se puede sobreescribir con variables de entorno, por ejemplo:
#   BUCKET=mi-bucket ./scripts/deploy.sh
#
set -euo pipefail

export AWS_REGION="${AWS_REGION:-us-east-1}"
export AWS_DEFAULT_REGION="$AWS_REGION"

ACCOUNT_ID="${ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text)}"
export ACCOUNT_ID

# En AWS Academy Learner Lab NO se pueden crear roles IAM; se usa LabRole.
export ROLE_ARN="${ROLE_ARN:-arn:aws:iam::${ACCOUNT_ID}:role/LabRole}"

export PROJECT="${PROJECT:-logging-system}"
export BUCKET="${BUCKET:-${PROJECT}-${ACCOUNT_ID}}"
export INPUT_PREFIX="input/"

export LOGS_TABLE="${LOGS_TABLE:-Logs}"
export ALERTS_TABLE="${ALERTS_TABLE:-SecurityAlerts}"
export LOGS_GSI="${LOGS_GSI:-ByArrival}"
export LOGS_GSI_PK_VALUE="LOG"

export SPLIT_LAMBDA="${PROJECT}-split-batch"
export ALERTS_LAMBDA="${PROJECT}-get-alerts"
export LOGS_LAMBDA="${PROJECT}-get-logs"
export LAMBDA_RUNTIME="python3.12"

export STATE_MACHINE="${PROJECT}-classifier"
export STATE_MACHINE_ARN="arn:aws:states:${AWS_REGION}:${ACCOUNT_ID}:stateMachine:${STATE_MACHINE}"

export RULE_NAME="${PROJECT}-s3-to-sfn"
export API_NAME="${PROJECT}-api"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ROOT_DIR
export DIST_DIR="${ROOT_DIR}/dist"

lambda_arn() {
  echo "arn:aws:lambda:${AWS_REGION}:${ACCOUNT_ID}:function:$1"
}

log() { echo "==> $*"; }
