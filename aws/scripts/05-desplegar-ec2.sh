#!/usr/bin/env bash
# Despliega el sistema en la EC2: sube los archivos, deja los secretos en Parameter Store
# y levanta los contenedores con las imagenes de ECR. Ejecutar desde la raiz del repositorio.
#
# Variables opcionales:
#   IMAGE_TAG  etiqueta de las imagenes en ECR (por defecto: latest)
#   SSH_KEY    ruta de la clave .pem (por defecto: ~/.ssh/labsuser.pem)
set -euo pipefail
export MSYS_NO_PATHCONV=1

REGION="${AWS_REGION:-us-east-1}"
TAG="${IMAGE_TAG:-latest}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/labsuser.pem}"
SSH_OPTS="-i $SSH_KEY -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10"

CUENTA=$(aws sts get-caller-identity --query Account --output text)
REGISTRO="${CUENTA}.dkr.ecr.${REGION}.amazonaws.com"

echo ">> Secretos en Parameter Store (se crean solo si no existen)"
asegurar_parametro() {
  local nombre="/tienda/$1"
  if aws ssm get-parameter --name "$nombre" --region "$REGION" >/dev/null 2>&1; then
    echo "   $nombre ya existe"
  else
    aws ssm put-parameter --name "$nombre" --type SecureString --value "$2" \
      --region "$REGION" >/dev/null
    echo "   $nombre creado"
  fi
}
asegurar_parametro mysql_root_password "$(openssl rand -hex 12)"
asegurar_parametro db_password "$(openssl rand -hex 12)"
asegurar_parametro jwt_secret "$(openssl rand -hex 32)"
asegurar_parametro gateway_secret "$(openssl rand -hex 24)"

COLA_URL=$(aws sqs get-queue-url --queue-name "${COLA_PEDIDOS:-tienda-pedidos}" \
  --region "$REGION" --query QueueUrl --output text)

IP=$(aws ec2 describe-addresses --region "$REGION" --filters Name=tag:Name,Values=tienda-eip \
  --query 'Addresses[0].PublicIp' --output text)
if [ "$IP" = "None" ]; then
  echo "No hay IP elastica: ejecuta antes aws/scripts/04-crear-ec2.sh"; exit 1
fi
echo ">> Destino: ec2-user@$IP"

echo ">> Esperando a que la instancia acepte SSH y tenga Docker"
for i in $(seq 1 30); do
  if ssh $SSH_OPTS "ec2-user@$IP" "docker compose version" >/dev/null 2>&1; then break; fi
  sleep 10
  [ "$i" -eq 30 ] && { echo "La instancia no respondio a tiempo"; exit 1; }
done

echo ">> Subiendo archivos"
scp $SSH_OPTS aws/deploy/docker-compose.aws.yml aws/deploy/nginx.conf.template \
  aws/deploy/desplegar-remoto.sh scripts-db/init-databases.sql "ec2-user@$IP:/opt/tienda/"

echo ">> Desplegando"
ssh $SSH_OPTS "ec2-user@$IP" "bash /opt/tienda/desplegar-remoto.sh '$REGISTRO' '$TAG' '$COLA_URL' '$REGION'"

echo ">> Listo: http://$IP/health"
