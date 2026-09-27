# Práctica 2: Logging System — Reporte

**Equipo:** ___
**Integrantes:** ___
**Materia:** Desarrollo en la Nube (Prof. Marcela Rosales, ITESO)
**Fecha:** ___ de octubre de 2026

## Descripción del proyecto

El proyecto es un sistema serverless en AWS que ingiere logs de un servidor OpenSSH, los clasifica como normales o sospechosos y expone los resultados para consulta por HTTP.

El flujo inicia con el script `start_logging.sh`, que lee el log de ejemplo (dataset loghub OpenSSH) línea por línea, agrupa líneas hasta juntar aproximadamente 1 KB por batch y sube cada batch a un bucket de S3 esperando N segundos entre uno y otro. El bucket tiene activadas las notificaciones a EventBridge, y una regla que escucha los eventos "Object Created" bajo el prefijo `input/` inicia una ejecución de una máquina de estados de Step Functions por cada archivo.

La máquina de estados tiene dos etapas. La primera es una Lambda (`split-batch`) que descarga el batch, lo separa en líneas individuales y a cada una le agrega el `LastModified` del objeto en S3, es decir la hora real en que llegó el batch. La segunda es un estado Map que procesa cada línea: un Choice la clasifica como sospechosa si contiene `Invalid user` o `POSSIBLE BREAK-IN ATTEMPT` (asignando severidad MEDIUM o HIGH) y como normal en cualquier otro caso, y un segundo Choice la dirige a la tabla de DynamoDB correspondiente: `SecurityAlerts` para las sospechosas y `Logs` para las normales. Ambas escrituras tienen Retry con backoff exponencial para manejar throttling.

La consulta se hace por un API Gateway de tipo HTTP API con dos rutas, cada una con su propia Lambda. `GET /alerts` regresa todas las alertas con id, timestamp, host, log y severity. `GET /logs?top=N` regresa los últimos N logs usando un índice secundario global de la tabla `Logs` cuya partition key es fija y cuya sort key es la hora de llegada del batch, lo que permite un Query con Limit y ScanIndexForward=false en vez de un Scan.

Toda la infraestructura se crea con scripts de AWS CLI y se elimina con `teardown.sh`.

_(≈ 300 palabras; recortar si excede)_

## Diagrama de arquitectura

Renderizar en https://mermaid.live y pegar la imagen:

```
flowchart LR
    S[start_logging.sh N] -->|batch ~1KB cada N s| B[(S3 bucket\ninput/)]
    B -->|Object Created| E[EventBridge rule]
    E --> SF

    subgraph SF[Step Functions]
        direction LR
        L1[SplitBatch\nLambda split-batch] --> M
        subgraph M[Map: ClassifyLines]
            direction LR
            C1{Classify\nInvalid user /\nBREAK-IN?} -->|sospechosa| P1[severity HIGH/MEDIUM]
            C1 -->|normal| P2[normal]
            P1 --> C2{RouteToTable}
            P2 --> C2
            C2 -->|sospechosa| W1[PutItem + Retry]
            C2 -->|normal| W2[PutItem + Retry]
        end
    end

    W1 --> T1[(DynamoDB\nSecurityAlerts)]
    W2 --> T2[(DynamoDB Logs\nGSI ByArrival)]

    U[Cliente] -->|GET /alerts| G[API Gateway\nHTTP API]
    U -->|GET /logs?top=N| G
    G --> LA[Lambda get-alerts] --> T1
    G --> LL[Lambda get-logs] -->|Query GSI\nLimit=N desc| T2
```

## Decisiones

- **Tamaño de batch:** 1 KB (el default de la práctica). _(Si se cambia, justificar aquí.)_
- **Severidad:** `POSSIBLE BREAK-IN ATTEMPT` = HIGH, `Invalid user` = MEDIUM.
- **Disparo S3 -> Step Functions:** vía EventBridge, porque S3 no puede invocar Step Functions directamente.
- **Rol:** `LabRole` (Learner Lab no permite crear roles IAM).

## Anexos (capturas)

1. S3: objetos llegando a `input/`
2. Step Functions: Graph view con líneas normales y sospechosas
3. DynamoDB: tablas `Logs` y `SecurityAlerts` con datos
4. API Gateway: rutas configuradas
5. Respuestas de `GET /alerts` y `GET /logs?top=N`
6. `teardown.sh` y `status.sh` mostrando recursos eliminados
