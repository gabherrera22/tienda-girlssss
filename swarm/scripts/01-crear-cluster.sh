#!/usr/bin/env bash
# Crea un cluster Docker Swarm simulado en tu PC:
# 1 manager + 2 workers (cada uno es un contenedor Docker-in-Docker)
# y un registro local de imagenes (registry) que comparten los nodos.
set -euo pipefail
export MSYS_NO_PATHCONV=1

RED=swarm-net

echo ">> Red y registro local"
docker network inspect "$RED" >/dev/null 2>&1 || docker network create "$RED"
docker inspect registry >/dev/null 2>&1 || docker run -d --name registry --network "$RED" -p 5000:5000 --restart unless-stopped registry:2

crear_nodo() {
  local nombre=$1
  shift
  if docker inspect "$nombre" >/dev/null 2>&1; then
    echo "$nombre ya existe"
    return
  fi
  docker run -d --restart unless-stopped --privileged --name "$nombre" --hostname "$nombre" --network "$RED" \
    -e DOCKER_TLS_CERTDIR="" "$@" \
    docker:27-dind --insecure-registry=registry:5000
}

echo ">> Creando nodos"
crear_nodo manager1 -p 8081-8085:8081-8085
crear_nodo worker1
crear_nodo worker2

echo ">> Esperando que arranquen los daemons de Docker"
for n in manager1 worker1 worker2; do
  until docker exec "$n" docker info >/dev/null 2>&1; do sleep 2; done
  echo "   $n listo"
done

echo ">> Inicializando Swarm en el manager"
estado=$(docker exec manager1 docker info --format '{{.Swarm.LocalNodeState}}')
if [ "$estado" != "active" ]; then
  docker exec manager1 docker swarm init --advertise-addr eth0
fi

TOKEN=$(docker exec manager1 docker swarm join-token -q worker)
for w in worker1 worker2; do
  estado=$(docker exec "$w" docker info --format '{{.Swarm.LocalNodeState}}')
  if [ "$estado" != "active" ]; then
    docker exec "$w" docker swarm join --token "$TOKEN" manager1:2377
  fi
done

echo ">> Nodos del cluster"
docker exec manager1 docker node ls
