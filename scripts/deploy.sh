#!/usr/bin/env bash
#
# deploy.sh
# Crea TODA la infraestructura en orden:
#   S3 -> DynamoDB -> Lambdas -> Step Functions -> EventBridge -> API Gateway
#
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"${SCRIPT_DIR}/01-create-s3-bucket.sh"
"${SCRIPT_DIR}/02-create-dynamodb.sh"
"${SCRIPT_DIR}/03-deploy-lambdas.sh"
"${SCRIPT_DIR}/04-create-state-machine.sh"
"${SCRIPT_DIR}/05-create-eventbridge-rule.sh"
"${SCRIPT_DIR}/06-create-api.sh"

echo
echo "Infraestructura desplegada. Siguiente paso:"
echo "  ./start_logging.sh 30"
