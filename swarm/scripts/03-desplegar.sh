#!/usr/bin/env bash
# Crea los secretos desde .env y despliega el stack "tienda" en el cluster.
set -euo pipefail
export MSYS_NO_PATHCONV=1

leer() {
  grep "^$1=" .env | head -1 | cut -d= -f2- | tr -d '\r\n'
}

crear_secreto() {
  local nombre=$1
  local valor=$2
  if docker exec manager1 docker secret inspect "$nombre" >/dev/null 2>&1; then
    echo "secreto $nombre ya existe"
  else
    printf '%s' "$valor" | docker exec -i manager1 docker secret create "$nombre" -
  fi
}

crear_secreto mysql_root_password "$(leer MYSQL_ROOT_PASSWORD)"
crear_secreto db_password "$(leer DB_PASSWORD)"
crear_secreto jwt_secret "$(leer JWT_SECRET)"

docker exec manager1 mkdir -p /stack
docker cp swarm/stack.yml manager1:/stack/stack.yml
docker cp scripts-db/init-databases.sql manager1:/stack/init-databases.sql

docker exec manager1 docker stack deploy -c /stack/stack.yml tienda
echo
docker exec manager1 docker stack services tienda
