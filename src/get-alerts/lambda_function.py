"""
Lambda: get-alerts   (GET /alerts)

Regresa todas las alertas registradas en la tabla SecurityAlerts con
id, timestamp, host, log y severity, ordenadas de la mas reciente a la
mas antigua segun la hora en que llego el batch a S3.
"""

import json
import os

import boto3

dynamodb = boto3.resource("dynamodb")
TABLE = dynamodb.Table(os.environ.get("ALERTS_TABLE", "SecurityAlerts"))

FIELDS = ("id", "timestamp", "host", "log", "severity")


def scan_all():
    items = []
    kwargs = {}
    while True:
        page = TABLE.scan(**kwargs)
        items.extend(page.get("Items", []))
        if "LastEvaluatedKey" not in page:
            return items
        kwargs["ExclusiveStartKey"] = page["LastEvaluatedKey"]


def lambda_handler(event, context):
    items = scan_all()
    items.sort(key=lambda i: (i.get("arrived_at", ""), i.get("line_no", 0)), reverse=True)

    alerts = [{f: item.get(f, "") for f in FIELDS} for item in items]

    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({"count": len(alerts), "alerts": alerts}, default=str),
    }
