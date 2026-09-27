# Guion del video (5-10 min)

Requisito: todo corre en la nube. Espera entre batches: **no menos de 30 s**.

## Antes de grabar

- [ ] Credenciales del Learner Lab frescas (`aws sts get-caller-identity` responde).
- [ ] `./scripts/deploy.sh` ya corrió sin errores.
- [ ] `./scripts/status.sh` muestra todo `[OK]`.
- [ ] Consola AWS abierta en pestañas: S3 (bucket), Step Functions, DynamoDB (2 tablas), Lambda, API Gateway.
- [ ] Dos terminales: una para `start_logging.sh`, otra para `query-api.sh`.

## Secuencia

1. **Infra (rubro 1)** — 1 min
   Mostrar `./scripts/status.sh` y recorrer rápido en consola: bucket, tablas, 3 Lambdas, state machine, API con sus 2 rutas.

2. **Envío de batches (rubro 2)** — 2-3 min
   Terminal 1: `./start_logging.sh 30`. Mostrar que crea los batches (~1KB) y empieza a subir.
   Consola S3: refrescar `input/` y ver cómo aparecen `openssh-<ts>.log`.

3. **Step Functions (rubros 3, 4, 5, 6)** — 2 min
   Abrir una ejecución -> Graph view. Mostrar:
   - `SplitBatch` con la salida (`count`, `lines`).
   - Dentro del Map una iteración que fue a `SaveAlert` (línea con `Invalid user`) y otra a `SaveLog`.
   - En la definición: el bloque `Retry` de `SaveAlert` / `SaveLog`.

4. **DynamoDB** — 1 min
   Explorar items de `Logs` y `SecurityAlerts`; refrescar para ver que siguen entrando.
   En `Logs` -> Indexes: mostrar el GSI `ByArrival` (gsi_pk / arrived_at).

5. **API (rubros 7, 8)** — 1 min
   Terminal 2:
   `./scripts/query-api.sh alerts`
   `./scripts/query-api.sh logs 5`
   Señalar id, timestamp, host, log, severity en alerts; y que logs vienen ordenados por `arrived_at` descendente.
   Mostrar en consola API Gateway las rutas `GET /alerts` y `GET /logs` y sus integraciones.

6. **Teardown (rubro 10)** — 1-2 min
   Ctrl+C en Terminal 1 si sigue corriendo.
   `./scripts/teardown.sh` -> escribir `si`.
   `./scripts/status.sh` -> todo `[AUSENTE]`.
   Refrescar consola: S3 sin bucket, DynamoDB sin tablas, Lambda vacía, Step Functions vacía, API Gateway vacío.

## Líneas útiles para mostrar clasificación

En el dataset OpenSSH_2k.log hay muchas líneas `Invalid user ... from ...` y algunas
`POSSIBLE BREAK-IN ATTEMPT!`. Con batches de 1KB casi cada batch trae ambas clases,
así que basta con abrir cualquier ejecución.
