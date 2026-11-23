#!/usr/bin/env bash
# Borra el cluster simulado completo (nodos, registro y red).
export MSYS_NO_PATHCONV=1
docker rm -fv manager1 worker1 worker2 registry 2>/dev/null
docker network rm swarm-net 2>/dev/null
echo "Cluster eliminado"
