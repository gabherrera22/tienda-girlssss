#!/usr/bin/env bash
# Crea (o reutiliza) la cola SQS donde "pedidos" publica los pedidos nuevos.
# Es idempotente: se puede ejecutar varias veces sin duplicar nada.
set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"
COLA="${COLA_PEDIDOS:-tienda-pedidos}"

echo ">> Creando cola $COLA en $REGION"
URL=$(aws sqs create-queue \
  --queue-name "$COLA" \
  --region "$REGION" \
  --attributes VisibilityTimeout=60,MessageRetentionPeriod=86400,ReceiveMessageWaitTimeSeconds=10 \
  --query QueueUrl --output text)

ARN=$(aws sqs get-queue-attributes \
  --queue-url "$URL" \
  --region "$REGION" \
  --attribute-names QueueArn \
  --query Attributes.QueueArn --output text)

echo "URL: $URL"
echo "ARN: $ARN"
