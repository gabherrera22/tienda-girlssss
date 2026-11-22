#!/usr/bin/env bash
# Se ejecuta DENTRO de la EC2 (lo invoca 05-desplegar-ec2.sh).
# Uso: desplegar-remoto.sh <registro-ecr> <etiqueta> <url-cola-sqs> <region>
set -euo pipefail

REGISTRO="$1"
TAG="$2"
COLA_URL="$3"
REGION="${4:-us-east-1}"

cd /opt/tienda

leer() {
  aws ssm get-parameter --name "/tienda/$1" --with-decryption \
    --query Parameter.Value --output text --region "$REGION"
}

echo ">> Generando .env desde Parameter Store"
umask 077
cat > .env <<EOF2
MYSQL_ROOT_PASSWORD=$(leer mysql_root_password)
DB_PASSWORD=$(leer db_password)
JWT_SECRET=$(leer jwt_secret)
GATEWAY_SECRET=$(leer gateway_secret)
ECR_REGISTRY=$REGISTRO
IMAGE_TAG=$TAG
SQS_QUEUE_URL=$COLA_URL
AWS_REGION=$REGION
EOF2

echo ">> Iniciando sesion en ECR"
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$REGISTRO"

echo ">> Descargando imagenes ($TAG)"
docker compose -f docker-compose.aws.yml pull

echo ">> Levantando servicios"
docker compose -f docker-compose.aws.yml up -d --remove-orphans

echo ">> Estado"
docker compose -f docker-compose.aws.yml ps
