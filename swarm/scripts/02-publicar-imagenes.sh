#!/usr/bin/env bash
# Construye las imagenes y las sube al registro local para que los nodos las descarguen.
set -euo pipefail
export MSYS_NO_PATHCONV=1

docker compose build
for s in usuarios productos pedidos pagos envios; do
  docker tag "$s:1.0" "localhost:5000/$s:1.0"
  docker push "localhost:5000/$s:1.0"
done

echo ">> Imagenes en el registro:"
curl -s http://localhost:5000/v2/_catalog
echo
