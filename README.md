# Logging System (Serverless) — Práctica 2

Desarrollo en la Nube, ITESO. Módulo 5.

Sistema serverless que ingiere logs de servidores (OpenSSH, dataset loghub),
los clasifica como **normales** o **sospechosos** y expone los resultados por
API. Un script simula el envío de logs subiendo batches de ~1KB a S3 cada N
segundos; cada batch dispara una máquina de estados que separa las líneas,
las clasifica con un estado **Map** y las guarda con un estado **Choice** en la
tabla de DynamoDB correspondiente.

## Arquitectura

```
./start_logging.sh 30
      |  (batch ~1KB cada 30 s)
      v
S3  s3://<bucket>/input/openssh-<ts>.log
      |  EventBridge: "Object Created" (prefix input/)
      v
Step Functions  logging-system-classifier
      |
      |-- SplitBatch (Lambda split-batch): descarga el batch, lo separa en lineas
      |
      '-- ClassifyLines (Map, una iteracion por linea)
            |-- Classify (Choice): contiene "Invalid user" o "POSSIBLE BREAK-IN ATTEMPT"?
            |     -> sospechosa (severity HIGH / MEDIUM)  |  normal
            '-- RouteToTable (Choice)
                  |-- SaveAlert -> DynamoDB SecurityAlerts   (con Retry)
                  '-- SaveLog   -> DynamoDB Logs             (con Retry)

API Gateway (HTTP API)
   GET /alerts       -> Lambda get-alerts -> Scan SecurityAlerts
   GET /logs?top=N   -> Lambda get-logs   -> Query GSI ByArrival (Limit=N, ScanIndexForward=false)
```

### Tablas

| Tabla            | PK   | GSI `ByArrival`                                   |
|------------------|------|---------------------------------------------------|
| `Logs`           | `id` | PK fija `gsi_pk = "LOG"`, SK `arrived_at`          |
| `SecurityAlerts` | `id` | (no aplica)                                        |

`arrived_at` es el **LastModified del objeto en S3** (la hora real en que llegó
el batch), no el timestamp que trae la línea del log. Con ese GSI,
`GET /logs?top=N` hace un `Query` con `Limit=N` y `ScanIndexForward=false`
en lugar de un `Scan`.

### Clasificación y severidad

| Contiene                    | Clasificación | Tabla            | severity |
|-----------------------------|---------------|------------------|----------|
| `POSSIBLE BREAK-IN ATTEMPT` | sospechosa    | `SecurityAlerts` | `HIGH`   |
| `Invalid user`              | sospechosa    | `SecurityAlerts` | `MEDIUM` |
| cualquier otra              | normal        | `Logs`           | —        |

### Retry

Las dos tareas `dynamodb:putItem` tienen `Retry` con backoff exponencial para
`DynamoDB.ProvisionedThroughputExceededException`, `DynamoDB.ThrottlingException`,
`DynamoDB.RequestLimitExceeded` y `DynamoDB.InternalServerError` (6 intentos),
más un segundo bloque para `States.TaskFailed`.

## Estructura

```
Practica02/
├── README.md
├── start_logging.sh               # ./start_logging.sh 30
├── scripts/
│   ├── 00-config.sh               # variables compartidas (bucket, tablas, nombres, LabRole)
│   ├── 01-create-s3-bucket.sh
│   ├── 02-create-dynamodb.sh      # Logs (+ GSI ByArrival) y SecurityAlerts
│   ├── 03-deploy-lambdas.sh       # empaqueta y despliega las 3 Lambdas
│   ├── 04-create-state-machine.sh
│   ├── 05-create-eventbridge-rule.sh
│   ├── 06-create-api.sh           # HTTP API con GET /alerts y GET /logs
│   ├── deploy.sh                  # corre 01..06 en orden
│   ├── split-log.sh               # parte el log en batches de ~1KB
│   ├── send-logs.sh               # sube batches a S3 cada N segundos
│   ├── query-api.sh               # ./query-api.sh alerts | logs 5
│   ├── status.sh                  # estado de todos los recursos
│   └── teardown.sh                # elimina todo
├── statemachine/
│   └── definition.asl.json        # Map + Choice + Retry
├── src/
│   ├── split-batch/lambda_function.py
│   ├── get-alerts/lambda_function.py
│   └── get-logs/lambda_function.py
└── docs/
    ├── reporte.md                 # borrador del reporte (2 hojas)
    └── video-checklist.md         # guion del video demostrativo
```

## Requisitos

- AWS CLI v2 configurado (en Learner Lab: pegar las credenciales de
  *AWS Details > AWS CLI: Show* en `~/.aws/credentials`).
- `bash`, `curl`, `zip`. Opcional: `jq`.
- Región `us-east-1` (default). El rol usado es `LabRole` (en Learner Lab no se
  pueden crear roles IAM). Se puede cambiar con `ROLE_ARN=...`.

## Cómo correrlo

```bash
chmod +x start_logging.sh scripts/*.sh

# 1. Toda la infraestructura (S3, DynamoDB, Lambdas, Step Functions, EventBridge, API)
./scripts/deploy.sh

# 2. Enviar logs: descarga OpenSSH_2k.log, lo parte en batches de ~1KB y sube uno cada 30 s
./start_logging.sh 30

# 3. Consultar (en otra terminal)
./scripts/query-api.sh alerts
./scripts/query-api.sh logs 5

# 4. Ver estado / conteos
./scripts/status.sh
```

Cada script es idempotente: se puede volver a correr sin romper nada.

Variables opcionales: `BUCKET`, `AWS_REGION`, `ROLE_ARN`, `PROJECT`,
`LOGS_TABLE`, `ALERTS_TABLE`. Ejemplo: `BUCKET=mi-bucket ./scripts/deploy.sh`.

## Eliminar los recursos

```bash
./scripts/teardown.sh          # pide confirmación
./scripts/status.sh            # todo debe salir [AUSENTE]
```

Borra la regla de EventBridge, la máquina de estados, el API, las 3 Lambdas,
las 2 tablas y el bucket (vaciándolo primero). No borra `LabRole`.

## Notas

- Tamaño de batch: ~1KB (default `1024` bytes; `./start_logging.sh 30 512` para otro tamaño).
- Cada corrida de `start_logging.sh` genera batches con timestamp nuevo, así que
  siempre llegan como objetos nuevos a S3.
- La máquina de estados recibe el evento de EventBridge y toma `bucket` y `key`
  de `$.detail`.
