"""
Lambda: split-batch

Primer paso de la maquina de estados. Recibe el bucket y la key del batch
que acaba de llegar a S3, lo descarga y lo separa en lineas individuales.
Cada linea sale como un objeto listo para que el estado Map la clasifique
y el estado Choice la guarde en DynamoDB.

Entrada (la construye la maquina de estados a partir del evento de EventBridge):
    {"bucket": "mi-bucket", "key": "input/openssh-123.log"}

Salida:
    {
      "bucket": "...", "key": "...", "arrived_at": "2026-09-27T21:40:12Z",
      "count": 9,
      "lines": [
        {"id": "...", "timestamp": "Dec 10 06:55:46", "host": "LabSZ",
         "program": "sshd", "pid": "24200",
         "log": "Invalid user webmaster from 173.234.31.186",
         "raw": "<linea completa>", "arrived_at": "...", "batch_key": "...",
         "line_no": 1, "gsi_pk": "LOG"}
      ]
    }

arrived_at es el LastModified del objeto en S3 (la hora real en que llego el
batch), NO el timestamp que trae el log. Es la sort key del GSI de la tabla Logs.
"""

import re
import uuid

import boto3

s3 = boto3.client("s3")

# <mes> <dia> <hh:mm:ss> <hostname> <program>[<pid>]: <mensaje>
LINE_RE = re.compile(
    r"^(?P<timestamp>[A-Z][a-z]{2}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2})\s+"
    r"(?P<host>\S+)\s+"
    r"(?P<program>[^\[:\s]+)"
    r"(?:\[(?P<pid>\d+)\])?:\s?"
    r"(?P<log>.*)$"
)

GSI_PK_VALUE = "LOG"


def parse_line(raw):
    match = LINE_RE.match(raw)
    if not match:
        # Linea fuera de formato: se conserva completa en "log".
        return {"timestamp": "", "host": "", "program": "", "pid": "", "log": raw}
    d = match.groupdict()
    return {
        "timestamp": d["timestamp"],
        "host": d["host"],
        "program": d["program"],
        "pid": d["pid"] or "",
        "log": d["log"],
    }


def lambda_handler(event, context):
    bucket = event["bucket"]
    key = event["key"]

    head = s3.head_object(Bucket=bucket, Key=key)
    arrived_at = head["LastModified"].strftime("%Y-%m-%dT%H:%M:%SZ")

    body = s3.get_object(Bucket=bucket, Key=key)["Body"].read()
    content = body.decode("utf-8", errors="replace")

    lines = []
    for line_no, raw in enumerate(content.splitlines(), start=1):
        raw = raw.rstrip("\r")
        if not raw.strip():
            continue
        item = parse_line(raw)
        item.update(
            {
                "id": str(uuid.uuid4()),
                "raw": raw,
                "arrived_at": arrived_at,
                "batch_key": key,
                "line_no": line_no,
                "gsi_pk": GSI_PK_VALUE,
            }
        )
        lines.append(item)

    print(f"s3://{bucket}/{key}: {len(lines)} lineas, arrived_at={arrived_at}")

    return {
        "bucket": bucket,
        "key": key,
        "arrived_at": arrived_at,
        "count": len(lines),
        "lines": lines,
    }
