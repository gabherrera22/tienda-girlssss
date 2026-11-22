#!/usr/bin/env bash
# Crea el API Gateway (REST) que protege el backend de la EC2.
#  - Exige una API key (cabecera x-api-key) a quien llame desde internet.
#  - Reenvia /api/{proxy+} a nginx (puerto 80 de la EC2) y le agrega la
#    cabecera secreta X-Origin-Verify, que nginx exige para dejar pasar.
#  - Aplica un plan de uso (limite de peticiones por segundo y por dia).
# Es idempotente: se puede ejecutar varias veces.
set -euo pipefail
export MSYS_NO_PATHCONV=1   # evita que Git Bash convierta rutas como /api o /tienda

REGION="${AWS_REGION:-us-east-1}"
API_NOMBRE="${API_NOMBRE:-tienda-api}"
ETAPA="${ETAPA:-prod}"
PLAN_NOMBRE="${PLAN_NOMBRE:-tienda-plan}"
KEY_NOMBRE="${KEY_NOMBRE:-tienda-cliente-web}"
TMP_JSON=".integracion-tmp.json"
trap 'rm -f "$TMP_JSON"' EXIT

vacio() { [ -z "$1" ] || [ "$1" = "None" ] || [ "$1" = "null" ]; }

echo ">> Buscando la IP de la EC2 (tienda-backend)"
IP=$(aws ec2 describe-instances --region "$REGION" \
  --filters Name=tag:Name,Values=tienda-backend Name=instance-state-name,Values=running \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
if vacio "$IP"; then
  echo "No encuentro la EC2 encendida. Inicia el laboratorio y enciende la instancia."; exit 1
fi
echo "   IP: $IP"

echo ">> Leyendo el secreto del gateway desde Parameter Store"
SECRETO=$(aws ssm get-parameter --region "$REGION" --name /tienda/gateway_secret \
  --with-decryption --query Parameter.Value --output text)

echo ">> API REST $API_NOMBRE"
API_ID=$(aws apigateway get-rest-apis --region "$REGION" \
  --query "items[?name=='$API_NOMBRE'].id | [0]" --output text)
if vacio "$API_ID"; then
  API_ID=$(aws apigateway create-rest-api --region "$REGION" --name "$API_NOMBRE" \
    --description "Entrada publica de la tienda de las girlssss" \
    --endpoint-configuration types=REGIONAL --query id --output text)
  echo "   creada: $API_ID"
else
  echo "   ya existe: $API_ID"
fi

echo ">> Recursos /api y /api/{proxy+}"
RAIZ_ID=$(aws apigateway get-resources --region "$REGION" --rest-api-id "$API_ID" \
  --query "items[?path=='/'].id | [0]" --output text)

API_RES=$(aws apigateway get-resources --region "$REGION" --rest-api-id "$API_ID" \
  --query "items[?path=='/api'].id | [0]" --output text)
if vacio "$API_RES"; then
  API_RES=$(aws apigateway create-resource --region "$REGION" --rest-api-id "$API_ID" \
    --parent-id "$RAIZ_ID" --path-part api --query id --output text)
fi

PROXY_RES=$(aws apigateway get-resources --region "$REGION" --rest-api-id "$API_ID" \
  --query "items[?path=='/api/{proxy+}'].id | [0]" --output text)
if vacio "$PROXY_RES"; then
  PROXY_RES=$(aws apigateway create-resource --region "$REGION" --rest-api-id "$API_ID" \
    --parent-id "$API_RES" --path-part '{proxy+}' --query id --output text)
fi

echo ">> Metodo ANY con API key obligatoria"
# Se borra y se recrea para que un cambio de IP o de secreto quede aplicado.
aws apigateway delete-method --region "$REGION" --rest-api-id "$API_ID" \
  --resource-id "$PROXY_RES" --http-method ANY >/dev/null 2>&1 || true

aws apigateway put-method --region "$REGION" --rest-api-id "$API_ID" \
  --resource-id "$PROXY_RES" --http-method ANY \
  --authorization-type NONE --api-key-required \
  --request-parameters method.request.path.proxy=true >/dev/null

echo ">> Integracion con nginx (agrega la cabecera secreta)"
# El JSON va a un archivo temporal para que el secreto no aparezca en la linea de comandos.
cat > "$TMP_JSON" <<EOF
{
  "integration.request.path.proxy": "method.request.path.proxy",
  "integration.request.header.X-Origin-Verify": "'$SECRETO'"
}
EOF

aws apigateway put-integration --region "$REGION" --rest-api-id "$API_ID" \
  --resource-id "$PROXY_RES" --http-method ANY \
  --type HTTP_PROXY --integration-http-method ANY \
  --uri "http://$IP/api/{proxy}" \
  --request-parameters "file://$TMP_JSON" \
  --timeout-in-millis 29000 >/dev/null

echo ">> Publicando la etapa $ETAPA"
aws apigateway create-deployment --region "$REGION" --rest-api-id "$API_ID" \
  --stage-name "$ETAPA" --description "Despliegue $(date +%Y-%m-%d_%H:%M)" >/dev/null

echo ">> API key $KEY_NOMBRE"
KEY_ID=$(aws apigateway get-api-keys --region "$REGION" --name-query "$KEY_NOMBRE" \
  --query 'items[0].id' --output text)
if vacio "$KEY_ID"; then
  KEY_ID=$(aws apigateway create-api-key --region "$REGION" --name "$KEY_NOMBRE" \
    --enabled --query id --output text)
  echo "   creada"
else
  echo "   ya existe"
fi

echo ">> Plan de uso $PLAN_NOMBRE"
PLAN_ID=$(aws apigateway get-usage-plans --region "$REGION" \
  --query "items[?name=='$PLAN_NOMBRE'].id | [0]" --output text)
if vacio "$PLAN_ID"; then
  PLAN_ID=$(aws apigateway create-usage-plan --region "$REGION" --name "$PLAN_NOMBRE" \
    --throttle burstLimit=20,rateLimit=10 --quota limit=10000,period=DAY \
    --api-stages apiId="$API_ID",stage="$ETAPA" --query id --output text)
  echo "   creado"
else
  echo "   ya existe"
fi

aws apigateway create-usage-plan-key --region "$REGION" --usage-plan-id "$PLAN_ID" \
  --key-id "$KEY_ID" --key-type API_KEY >/dev/null 2>&1 || true

URL="https://$API_ID.execute-api.$REGION.amazonaws.com/$ETAPA"
echo
echo ">> Listo"
echo "   URL base:  $URL"
echo "   Ejemplo:   $URL/api/productos"
echo "   Tu API key (no la pegues en el chat ni la subas a Git):"
echo "   aws apigateway get-api-key --api-key $KEY_ID --include-value --query value --output text"
