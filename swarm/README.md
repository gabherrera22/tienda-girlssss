# Despliegue en Docker Swarm

Este directorio contiene todo lo necesario para crear un clúster Docker Swarm
(1 manager + 2 workers) y desplegar en él los 5 microservicios de la tienda
junto con MySQL.

El clúster se **simula en un solo equipo**: cada nodo es un contenedor
Docker-in-Docker, y un registro local (`registry`) entrega las imágenes a los
nodos. Los comandos de Swarm son los mismos que en máquinas reales, de modo que
la guía sirve también para un clúster en la nube.

## Arquitectura

```
Tu equipo (Docker Desktop)
├── registry   → registro de imágenes compartido por los nodos (puerto 5000)
├── manager1   → nodo manager (publica los puertos 8081-8085 al equipo)
├── worker1    → nodo worker
└── worker2    → nodo worker

Stack "tienda" (red overlay tienda-net)
├── mysql      → 1 réplica, fija en el manager (volumen mysql_data)
├── usuarios   → 1 réplica, puerto 8081
├── productos  → 1 réplica, puerto 8082
├── pedidos    → 1 réplica, puerto 8083
├── pagos      → 1 réplica, puerto 8084
└── envios     → 1 réplica, puerto 8085
```

## Requisitos

- Docker Desktop en ejecución (se recomiendan al menos 5 GB de memoria para Docker).
- Git Bash (Windows) o cualquier shell Bash.
- Un archivo `.env` en la raíz del repositorio (se crea a partir de `.env.example`).

## Paso a paso

### 1. Crear el archivo `.env`

```bash
cat > .env <<EOF2
MYSQL_ROOT_PASSWORD=$(openssl rand -hex 12)
DB_PASSWORD=$(openssl rand -hex 12)
JWT_SECRET=$(openssl rand -hex 32)
EOF2
```

El archivo `.env` no se sube a Git. Sus valores se convierten en **Docker secrets**
al desplegar.

### 2. Crear el clúster

```bash
bash swarm/scripts/01-crear-cluster.sh
```

Crea la red, el registro y los tres nodos, inicializa Swarm en `manager1` y une
`worker1` y `worker2`. Al final muestra la tabla de nodos:

```
docker exec manager1 docker node ls
```

### 3. Publicar las imágenes

```bash
bash swarm/scripts/02-publicar-imagenes.sh
```

Construye las 5 imágenes y las sube al registro (`localhost:5000`). Los nodos las
descargan como `registry:5000/<servicio>:1.0`.

### 4. Desplegar el stack

```bash
bash swarm/scripts/03-desplegar.sh
```

Crea los secretos `mysql_root_password`, `db_password` y `jwt_secret`, copia
`stack.yml` y el script SQL al manager y ejecuta `docker stack deploy`.

### 5. Verificar

```bash
docker exec manager1 docker stack services tienda
docker exec manager1 docker stack ps tienda --filter "desired-state=running"

for p in 8081 8082 8083 8084 8085; do
  echo -n "$p -> "; curl -s http://localhost:$p/actuator/health; echo
done
```

Las 6 réplicas deben quedar en `1/1` y los 5 endpoints responder `"status":"UP"`.
Tras el despliegue, los servicios pueden reiniciarse una o dos veces mientras MySQL
termina de iniciar; Swarm los reintenta solo.

## Agregar nodos al clúster

### Agregar un worker

```bash
docker run -d --restart unless-stopped --privileged --name worker3 --hostname worker3 \
  --network swarm-net -e DOCKER_TLS_CERTDIR="" \
  docker:27-dind --insecure-registry=registry:5000

TOKEN=$(docker exec manager1 docker swarm join-token -q worker)
docker exec worker3 docker swarm join --token "$TOKEN" manager1:2377
```

### Agregar un manager

```bash
docker run -d --restart unless-stopped --privileged --name manager2 --hostname manager2 \
  --network swarm-net -e DOCKER_TLS_CERTDIR="" \
  docker:27-dind --insecure-registry=registry:5000

TOKEN=$(docker exec manager1 docker swarm join-token -q manager)
docker exec manager2 docker swarm join --token "$TOKEN" manager1:2377
```

Para tolerar la caída de un manager se necesita un número **impar** de managers
(3 o 5), porque el consenso Raft exige mayoría.

### En máquinas reales

En servidores o instancias en la nube se usan los mismos comandos
(`docker swarm init --advertise-addr <IP>` y `docker swarm join --token ...`).
Los nodos deben poder comunicarse por los puertos **2377/tcp**, **7946/tcp y udp**
y **4789/udp**.

## Operación

### Escalar un servicio

```bash
docker exec manager1 docker service scale tienda_pedidos=3
docker exec manager1 docker service ps tienda_pedidos --filter "desired-state=running"
docker exec manager1 docker service scale tienda_pedidos=1
```

El *routing mesh* de Swarm reparte las peticiones entre todas las réplicas.

### Actualizar un servicio sin caída (rolling update)

```bash
docker exec manager1 docker service update --image registry:5000/pedidos:1.1 tienda_pedidos
```

Con `order: start-first` y `parallelism: 1`, Swarm levanta la réplica nueva antes
de retirar la anterior.

### Tolerancia a fallos

```bash
docker stop worker1
sleep 40
docker exec manager1 docker node ls
docker exec manager1 docker stack ps tienda --filter "desired-state=running"
docker start worker1
```

Cuando `worker1` queda `Down`, Swarm reprograma sus tareas en los demás nodos.

### Secretos

```bash
docker exec manager1 docker secret ls
docker exec manager1 docker service inspect tienda_usuarios \
  --format '{{json .Spec.TaskTemplate.ContainerSpec.Env}}'
```

Los secretos no aparecen en las variables de entorno del servicio.

### Eliminar todo

```bash
bash swarm/scripts/99-destruir.sh
```

## Decisiones técnicas

| Decisión | Motivo |
|---|---|
| Un servicio por microservicio, con su propia base de datos | **Escalabilidad:** cada servicio se escala de forma independiente con `docker service scale` |
| Réplicas configurables y routing mesh | **Escalabilidad y disponibilidad:** el tráfico se reparte entre réplicas y se redirige si una cae |
| `restart_policy: any` con espera de 10 s | **Disponibilidad:** los servicios que arrancan antes que MySQL se reintentan solos |
| `update_config` con `order: start-first` | **Disponibilidad:** actualizaciones sin corte |
| Healthcheck `/actuator/health` en cada imagen | **Disponibilidad:** Swarm reemplaza las réplicas no saludables |
| Docker secrets en lugar de variables de entorno | **Seguridad:** las credenciales no quedan en la definición del servicio |
| Límite de memoria y heap acotado por servicio | **Mantenibilidad:** consumo predecible y sin afectar a otros servicios |
| Un único `stack.yml` versionado en Git | **Mantenibilidad:** despliegue reproducible y revisable |
| MySQL fijo en el manager con volumen local | Simplifica el entorno de práctica |

### Limitaciones conocidas

- MySQL corre como una sola réplica con almacenamiento local: si el manager se
  pierde, se pierden los datos. En producción se usaría una base administrada
  (por ejemplo Amazon RDS, como en el diagrama de arquitectura).
- Con una réplica por servicio hay una breve interrupción mientras Swarm
  reubica un servicio tras la caída de un nodo. Los servicios críticos
  (por ejemplo `pagos`) deberían ejecutarse con dos o más réplicas en nodos distintos.
