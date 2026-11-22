#!/usr/bin/env bash
# Crea un repositorio de imagenes (ECR) por microservicio. Es idempotente.
set -euo pipefail
export MSYS_NO_PATHCONV=1

REGION="${AWS_REGION:-us-east-1}"

for s in usuarios productos pedidos pagos envios; do
  if aws ecr describe-repositories --repository-names "tienda/$s" --region "$REGION" >/dev/null 2>&1; then
    echo "tienda/$s ya existe"
  else
    aws ecr create-repository --repository-name "tienda/$s" --region "$REGION" \
      --image-scanning-configuration scanOnPush=true >/dev/null
    echo "creado tienda/$s"
  fi
done
