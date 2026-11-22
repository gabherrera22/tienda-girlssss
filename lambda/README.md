# Función serverless: procesar-pedido

Función AWS Lambda (Python 3.12) que consume la cola SQS `tienda-pedidos`.
Cada vez que el microservicio `pedidos` registra un pedido, publica un mensaje en
la cola; esta función lo recibe y lo procesa de forma asíncrona.

```
pedidos (productor) ──▶ SQS tienda-pedidos ──▶ Lambda procesar-pedido ──┬─▶ microservicio pagos (HTTP)
                                                                         └─▶ SNS tienda-notificaciones ──▶ correo
```

## Qué hace

1. **Valida** el mensaje (`pedidoId`, `usuarioId` y `montoTotal` mayor que cero).
2. **Registra el pago** llamando a `POST /api/pagos` del microservicio `pagos`
   (solo si la variable `PAGOS_URL` está definida).
3. **Notifica al cliente** publicando en un tópico SNS que envía un correo
   (solo si la variable `TOPIC_ARN` está definida).
4. Devuelve los mensajes que fallaron (`batchItemFailures`), de modo que SQS
   reintente **solo esos** y no el lote completo.

## Archivos

| Archivo | Descripción |
|---|---|
| `handler.py` | Código de la función |
| `test_handler.py` | Pruebas unitarias (no requieren AWS) |
| `evento-prueba.json` | Evento de ejemplo con formato SQS |
| `deploy.sh` | Crea o actualiza la función, el tópico SNS y la conexión con la cola |

## Configuración

| Variable | Obligatoria | Descripción |
|---|---|---|
| `TOPIC_ARN` | No | Tópico SNS para el correo. `deploy.sh` la define |
| `PAGOS_URL` | No | URL base del microservicio pagos, por ejemplo `http://1.2.3.4:8084` |

Parámetros de la función: runtime `python3.12`, handler `handler.lambda_handler`,
timeout 15 s, memoria 128 MB. La cola tiene `VisibilityTimeout=60`, mayor que el
timeout de la función, como recomienda AWS. La conexión con la cola usa lotes de
hasta 5 mensajes.

En AWS Academy (Learner Lab) no se pueden crear roles de IAM, por lo que la
función usa el rol existente `LabRole`.

## Despliegue

Requisitos: AWS CLI configurada (`aws sts get-caller-identity` responde) y la
cola creada con `aws/scripts/01-crear-cola.sh`.

```bash
export NOTIFY_EMAIL="tu-correo@ejemplo.cl"
# No definas PAGOS_URL en el despliegue actual: el microservicio pagos no es accesible
# desde internet (solo se llega por nginx, que exige una cabecera secreta que esta
# función no envía). Sin PAGOS_URL, la función solo publica la notificación en SNS.

bash lambda/deploy.sh
```

SNS envía un correo de confirmación: hay que abrirlo y pulsar **Confirm
subscription**, o no llegarán las notificaciones.

## Pruebas

### Pruebas unitarias

```bash
python -m unittest discover -s lambda -p "test_*.py" -v
```

### Invocación directa con un evento de ejemplo

```bash
aws lambda invoke --function-name tienda-procesar-pedido \
  --payload fileb://lambda/evento-prueba.json salida.json
cat salida.json
```
Debe responder `{"batchItemFailures": []}`.

### Prueba de extremo a extremo por la cola

```bash
URL=$(aws sqs get-queue-url --queue-name tienda-pedidos --query QueueUrl --output text)
aws sqs send-message --queue-url "$URL" \
  --message-body '{"pedidoId":10,"usuarioId":7,"montoTotal":15990}'
aws logs tail /aws/lambda/tienda-procesar-pedido --since 5m
```
En los registros debe aparecer `Procesando pedido 10 ...` y, si hay correo
confirmado, llega la notificación.

## Limitaciones conocidas

- **Idempotencia:** si el pago se registra pero la notificación falla, SQS
  reintenta el mensaje y el pago podría duplicarse. En producción se resolvería
  con una clave de idempotencia (por ejemplo, el `pedidoId`) en `pagos`.
- **Mensajes con error repetido:** conviene agregar una cola de mensajes muertos
  (*dead-letter queue*) para aislarlos tras varios reintentos.
