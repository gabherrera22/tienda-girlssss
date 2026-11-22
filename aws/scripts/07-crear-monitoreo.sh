#!/usr/bin/env bash
# Monitoreo con CloudWatch: alarmas y panel (dashboard) del sistema.
#  - Alarma: cola SQS con mensajes acumulados.
#  - Alarma: errores en la Lambda procesar-pedido.
#  - Alarma: errores 5XX en el API Gateway.
#  - Panel "tienda-girlssss" con las metricas de SQS, Lambda y API Gateway.
# Las alarmas avisan por correo usando el mismo tema SNS de las notificaciones.
# Es idempotente: se puede ejecutar varias veces.
set -euo pipefail
export MSYS_NO_PATHCONV=1

REGION="${AWS_REGION:-us-east-1}"
COLA="${COLA_PEDIDOS:-tienda-pedidos}"
FUNCION="${FUNCION_LAMBDA:-tienda-procesar-pedido}"
API_NOMBRE="${API_NOMBRE:-tienda-api}"
ETAPA="${ETAPA:-prod}"
PANEL="${PANEL:-tienda-girlssss}"
TMP_JSON=".panel-tmp.json"
trap 'rm -f "$TMP_JSON"' EXIT

echo ">> Buscando el tema SNS de notificaciones"
TOPIC_ARN=$(aws sns list-topics --region "$REGION" \
  --query "Topics[?contains(TopicArn,'tienda-notificaciones')].TopicArn | [0]" --output text)
if [ -z "$TOPIC_ARN" ] || [ "$TOPIC_ARN" = "None" ]; then
  echo "No encuentro el tema tienda-notificaciones. Ejecuta antes lambda/deploy.sh"; exit 1
fi

echo ">> Alarma: cola con mensajes acumulados"
aws cloudwatch put-metric-alarm --region "$REGION" \
  --alarm-name tienda-cola-acumulada \
  --alarm-description "La cola $COLA tiene mas de 50 mensajes pendientes: la Lambda no esta consumiendo" \
  --namespace AWS/SQS --metric-name ApproximateNumberOfMessagesVisible \
  --dimensions Name=QueueName,Value="$COLA" \
  --statistic Maximum --period 60 --evaluation-periods 2 \
  --threshold 50 --comparison-operator GreaterThanThreshold \
  --treat-missing-data notBreaching --alarm-actions "$TOPIC_ARN"

echo ">> Alarma: errores en la Lambda"
aws cloudwatch put-metric-alarm --region "$REGION" \
  --alarm-name tienda-lambda-errores \
  --alarm-description "La funcion $FUNCION registro errores" \
  --namespace AWS/Lambda --metric-name Errors \
  --dimensions Name=FunctionName,Value="$FUNCION" \
  --statistic Sum --period 60 --evaluation-periods 1 \
  --threshold 0 --comparison-operator GreaterThanThreshold \
  --treat-missing-data notBreaching --alarm-actions "$TOPIC_ARN"

echo ">> Alarma: errores 5XX en el API Gateway"
aws cloudwatch put-metric-alarm --region "$REGION" \
  --alarm-name tienda-api-5xx \
  --alarm-description "El API Gateway $API_NOMBRE devolvio errores 5XX" \
  --namespace AWS/ApiGateway --metric-name 5XXError \
  --dimensions Name=ApiName,Value="$API_NOMBRE" Name=Stage,Value="$ETAPA" \
  --statistic Sum --period 60 --evaluation-periods 1 \
  --threshold 0 --comparison-operator GreaterThanThreshold \
  --treat-missing-data notBreaching --alarm-actions "$TOPIC_ARN"

echo ">> Panel $PANEL"
cat > "$TMP_JSON" <<JSON
{
  "widgets": [
    {"type": "metric", "x": 0, "y": 0, "width": 12, "height": 6,
     "properties": {"title": "Cola SQS: mensajes pendientes", "region": "$REGION", "view": "timeSeries",
       "stat": "Maximum", "period": 60,
       "metrics": [["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", "$COLA"]]}},
    {"type": "metric", "x": 12, "y": 0, "width": 12, "height": 6,
     "properties": {"title": "Lambda: invocaciones y errores", "region": "$REGION", "view": "timeSeries",
       "stat": "Sum", "period": 60,
       "metrics": [["AWS/Lambda", "Invocations", "FunctionName", "$FUNCION"],
                   ["AWS/Lambda", "Errors", "FunctionName", "$FUNCION"]]}},
    {"type": "metric", "x": 0, "y": 6, "width": 12, "height": 6,
     "properties": {"title": "API Gateway: peticiones y errores", "region": "$REGION", "view": "timeSeries",
       "stat": "Sum", "period": 60,
       "metrics": [["AWS/ApiGateway", "Count", "ApiName", "$API_NOMBRE", "Stage", "$ETAPA"],
                   ["AWS/ApiGateway", "4XXError", "ApiName", "$API_NOMBRE", "Stage", "$ETAPA"],
                   ["AWS/ApiGateway", "5XXError", "ApiName", "$API_NOMBRE", "Stage", "$ETAPA"]]}},
    {"type": "metric", "x": 12, "y": 6, "width": 12, "height": 6,
     "properties": {"title": "Lambda: duracion (ms)", "region": "$REGION", "view": "timeSeries",
       "stat": "Average", "period": 60,
       "metrics": [["AWS/Lambda", "Duration", "FunctionName", "$FUNCION"]]}}
  ]
}
JSON
aws cloudwatch put-dashboard --region "$REGION" --dashboard-name "$PANEL" \
  --dashboard-body "file://$TMP_JSON" >/dev/null

echo
echo ">> Listo"
echo "   Panel:    https://$REGION.console.aws.amazon.com/cloudwatch/home?region=$REGION#dashboards:name=$PANEL"
echo "   Alarmas:  tienda-cola-acumulada, tienda-lambda-errores, tienda-api-5xx"
aws cloudwatch describe-alarms --region "$REGION" --alarm-name-prefix tienda- \
  --query 'MetricAlarms[].[AlarmName,StateValue]' --output text
