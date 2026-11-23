#!/usr/bin/env bash
# Despliega (o actualiza) la funcion Lambda, el topico SNS y la conexion con la cola SQS.
# Es idempotente: se puede ejecutar varias veces.
#
# Variables:
#   NOTIFY_EMAIL  (obligatoria) correo que recibira las notificaciones
#   PAGOS_URL     (opcional)    URL base del microservicio pagos, p. ej. http://1.2.3.4:8084
set -euo pipefail
export MSYS_NO_PATHCONV=1

REGION="${AWS_REGION:-us-east-1}"
FUNCION="${FUNCION:-tienda-procesar-pedido}"
COLA="${COLA_PEDIDOS:-tienda-pedidos}"
TOPICO="${TOPICO:-tienda-notificaciones}"
CORREO="${NOTIFY_EMAIL:?Define NOTIFY_EMAIL con el correo que recibira las notificaciones}"
PAGOS_URL="${PAGOS_URL:-}"
DIR="$(cd "$(dirname "$0")" && pwd)"
ZIP="$DIR/function.zip"
cd "$DIR"

CUENTA=$(aws sts get-caller-identity --query Account --output text)
ROL="arn:aws:iam::${CUENTA}:role/LabRole"   # Learner Lab: no se pueden crear roles

echo ">> Topico SNS $TOPICO"
TOPIC_ARN=$(aws sns create-topic --name "$TOPICO" --region "$REGION" --query TopicArn --output text)
aws sns subscribe --topic-arn "$TOPIC_ARN" --protocol email \
  --notification-endpoint "$CORREO" --region "$REGION" >/dev/null
echo "   Revisa tu correo y confirma la suscripcion de SNS"

echo ">> Empaquetando handler.py"
rm -f "$ZIP"
if command -v zip >/dev/null 2>&1; then
  (cd "$DIR" && zip -q function.zip handler.py)
else
  powershell -NoProfile -Command "Compress-Archive -Path '$(cygpath -w "$DIR/handler.py")' -DestinationPath '$(cygpath -w "$ZIP")' -Force"
fi

if [ -n "$PAGOS_URL" ]; then
  ENTORNO="{\"Variables\":{\"TOPIC_ARN\":\"$TOPIC_ARN\",\"PAGOS_URL\":\"$PAGOS_URL\"}}"
else
  ENTORNO="{\"Variables\":{\"TOPIC_ARN\":\"$TOPIC_ARN\"}}"
fi

echo ">> Funcion Lambda $FUNCION"
if aws lambda get-function --function-name "$FUNCION" --region "$REGION" >/dev/null 2>&1; then
  aws lambda update-function-code --function-name "$FUNCION" --region "$REGION" \
    --zip-file "fileb://function.zip" >/dev/null
  aws lambda wait function-updated --function-name "$FUNCION" --region "$REGION"
  aws lambda update-function-configuration --function-name "$FUNCION" --region "$REGION" \
    --timeout 15 --environment "$ENTORNO" >/dev/null
else
  aws lambda create-function --function-name "$FUNCION" --region "$REGION" \
    --runtime python3.12 --handler handler.lambda_handler --role "$ROL" \
    --timeout 15 --memory-size 128 --environment "$ENTORNO" \
    --zip-file "fileb://function.zip" >/dev/null
  aws lambda wait function-active-v2 --function-name "$FUNCION" --region "$REGION"
fi

echo ">> Conectando la cola $COLA con la funcion"
COLA_URL=$(aws sqs get-queue-url --queue-name "$COLA" --region "$REGION" --query QueueUrl --output text)
COLA_ARN=$(aws sqs get-queue-attributes --queue-url "$COLA_URL" --region "$REGION" \
  --attribute-names QueueArn --query Attributes.QueueArn --output text)
MAPEO=$(aws lambda list-event-source-mappings --function-name "$FUNCION" --region "$REGION" \
  --event-source-arn "$COLA_ARN" --query 'EventSourceMappings[0].UUID' --output text)
if [ "$MAPEO" = "None" ]; then
  aws lambda create-event-source-mapping --function-name "$FUNCION" --region "$REGION" \
    --event-source-arn "$COLA_ARN" --batch-size 5 \
    --function-response-types ReportBatchItemFailures >/dev/null
  echo "   Mapeo creado"
else
  echo "   Mapeo ya existe ($MAPEO)"
fi

echo ">> Listo"
echo "   Funcion: $FUNCION"
echo "   Topico:  $TOPIC_ARN"
# Asegura que la conexion cola -> Lambda quede activa (si estaba Disabled, la reactiva)
UUID_MAPEO=$(aws lambda list-event-source-mappings --function-name "$FUNCION" --region "$REGION" \
  --event-source-arn "$COLA_ARN" --query 'EventSourceMappings[0].UUID' --output text)
aws lambda update-event-source-mapping --uuid "$UUID_MAPEO" --region "$REGION" --enabled \
  --query State --output text
