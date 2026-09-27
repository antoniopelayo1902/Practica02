"""
Lambda: get-logs   (GET /logs?top=N)

Regresa los ultimos N logs de la tabla Logs. Usa el GSI ByArrival
(partition key fija gsi_pk="LOG", sort key arrived_at = LastModified del
batch en S3) con Query + Limit=N + ScanIndexForward=False, en lugar de Scan.
"""

import json
import os

import boto3
from boto3.dynamodb.conditions import Key

dynamodb = boto3.resource("dynamodb")
TABLE = dynamodb.Table(os.environ.get("LOGS_TABLE", "Logs"))
GSI = os.environ.get("LOGS_GSI", "ByArrival")
GSI_PK_VALUE = os.environ.get("LOGS_GSI_PK_VALUE", "LOG")

DEFAULT_TOP = 10
MAX_TOP = 100

FIELDS = ("id", "timestamp", "host", "log", "arrived_at")


def response(status, payload):
    return {
        "statusCode": status,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(payload, default=str),
    }


def parse_top(event):
    params = event.get("queryStringParameters") or {}
    raw = params.get("top", DEFAULT_TOP)
    try:
        top = int(raw)
    except (TypeError, ValueError):
        raise ValueError(f"top debe ser un entero, se recibio '{raw}'")
    if top < 1 or top > MAX_TOP:
        raise ValueError(f"top debe estar entre 1 y {MAX_TOP}")
    return top


def lambda_handler(event, context):
    try:
        top = parse_top(event)
    except ValueError as err:
        return response(400, {"error": str(err)})

    result = TABLE.query(
        IndexName=GSI,
        KeyConditionExpression=Key("gsi_pk").eq(GSI_PK_VALUE),
        ScanIndexForward=False,  # mas recientes primero
        Limit=top,
    )
    items = result.get("Items", [])
    logs = [{f: item.get(f, "") for f in FIELDS} for item in items]

    return response(200, {"top": top, "count": len(logs), "logs": logs})
