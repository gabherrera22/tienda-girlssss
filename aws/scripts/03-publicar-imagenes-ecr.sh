#!/usr/bin/env bash
# Construye las 5 imagenes y las sube a ECR con dos etiquetas: el SHA del commit y "latest".
# Ejecutar desde la raiz del repositorio.
set -euo pipefail
export MSYS_NO_PATHCONV=1

REGION="${AWS_REGION:-us-east-1}"
CUENTA=$(aws sts get-caller-identity --query Account --output text)
REGISTRO="${CUENTA}.dkr.ecr.${REGION}.amazonaws.com"
TAG=$(git rev-parse --short HEAD)

echo ">> Iniciando sesion en ECR"
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$REGISTRO"

echo ">> Construyendo imagenes"
docker compose build

for s in usuarios productos pedidos pagos envios; do
  echo ">> Publicando $s ($TAG y latest)"
  docker tag "$s:1.0" "$REGISTRO/tienda/$s:$TAG"
  docker tag "$s:1.0" "$REGISTRO/tienda/$s:latest"
  docker push "$REGISTRO/tienda/$s:$TAG"
  docker push "$REGISTRO/tienda/$s:latest"
done

echo ">> Imagenes en ECR:"
for s in usuarios productos pedidos pagos envios; do
  echo "tienda/$s: $(aws ecr list-images --repository-name "tienda/$s" --region "$REGION" --query 'length(imageIds)' --output text) etiquetas"
done
