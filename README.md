# Tienda de las girlssss — microservicios en la nube

Tienda online de cosmética basada en **5 microservicios Spring Boot** que se ejecutan
en contenedores Docker, se orquestan con **Docker Swarm** y se despliegan en **AWS**
mediante un pipeline de **GitHub Actions**. Los pedidos nuevos se procesan de forma
asíncrona con **SQS + Lambda**, y el acceso externo pasa por **API Gateway**.

## Arquitectura

```
Cliente → API Gateway (API key) → EC2: nginx → usuarios · productos · pedidos · pagos · envios → MySQL
                                                          │
                                                          └─ pedidos → SQS → Lambda → SNS (correo)
```

| Componente | Tecnología | Puerto |
|---|---|---|
| `usuarios` (login con JWT) | Spring Boot 4, Java 21 | 8081 |
| `productos` | Spring Boot 4, Java 21 | 8082 |
| `pedidos` (publica en SQS) | Spring Boot 4, Java 21 | 8083 |
| `pagos` | Spring Boot 4, Java 21 | 8084 |
| `envios` | Spring Boot 4, Java 21 | 8085 |
| Base de datos | MySQL 8 (una base por servicio) | 3306 |
| Cola de pedidos | Amazon SQS `tienda-pedidos` | — |
| Función serverless | AWS Lambda (Python 3.12) | — |
| Notificaciones | Amazon SNS (correo) | — |
| Entrada pública | Amazon API Gateway (REST) + nginx | 443 / 80 |

## Estructura del repositorio

| Carpeta o archivo | Contenido |
|---|---|
| `usuarios/ productos/ pedidos/ pagos/ envios/` | Código de cada microservicio, su `Dockerfile` y sus tests |
| `docker-compose.yml` | Entorno local completo (MySQL + 5 servicios) |
| `.env.example` | Plantilla de variables (copiar como `.env`) |
| `scripts-db/` | Scripts SQL (`init-databases.sql` crea las 5 bases) |
| `swarm/` | Stack de Docker Swarm, scripts del clúster y su README |
| `aws/` | Scripts de la nube (cola, ECR, EC2, despliegue, API Gateway) y archivos de despliegue |
| `lambda/` | Función serverless, tests, script de despliegue y README |
| `.github/workflows/ci-cd.yml` | Pipeline de CI/CD |

## Ejecutar en local

### Requisitos

Git, Docker Desktop (al menos 4 GB de memoria) y, para compilar sin Docker, JDK 21.

### Opción A: Docker Compose (recomendada)

```bash
git clone https://github.com/gabherrera22/tienda-girlssss.git
cd tienda-girlssss

cp .env.example .env        # abrir .env y reemplazar los tres valores
docker compose up -d --build
docker compose ps           # los 6 contenedores deben quedar "healthy"
```

Comprobar los servicios:

```bash
for p in 8081 8082 8083 8084 8085; do
  echo -n "$p -> "; curl -s http://localhost:$p/actuator/health; echo
done
```

Crear datos de prueba:

```bash
curl -s -X POST http://localhost:8081/api/usuarios -H "Content-Type: application/json" \
  -d '{"nombre":"Ana","email":"ana@correo.cl","password":"1234"}'
curl -s -X POST http://localhost:8081/api/usuarios/login -H "Content-Type: application/json" \
  -d '{"email":"ana@correo.cl","password":"1234"}'
curl -s -X POST http://localhost:8082/api/productos -H "Content-Type: application/json" \
  -d '{"sku":"SKU-1","nombre":"Crema","descripcion":"Hidratante","precio":9990,"stockActual":10}'
curl -s -X POST http://localhost:8083/api/pedidos -H "Content-Type: application/json" \
  -d '{"usuarioId":1,"montoTotal":9990}'
curl -s -X POST http://localhost:8084/api/pagos -H "Content-Type: application/json" \
  -d '{"pedidoId":1,"monto":9990,"metodoPago":"TARJETA"}'
curl -s -X POST http://localhost:8085/api/envios -H "Content-Type: application/json" \
  -d '{"pedidoId":1,"direccionDestino":"Av. Siempre Viva 123","numeroSeguimiento":"TRK-001"}'
```

Detener: `docker compose down` (conserva los datos) o `docker compose down -v` (los borra).

### Opción B: sin Docker

1. Instalar MySQL 8 y ejecutar `scripts-db/init-databases.sql` (crea las bases).
2. Definir la contraseña y levantar un servicio:

```bash
export DB_PASSWORD='Gabytha2026'
cd usuarios
./mvnw spring-boot:run
```

Variables disponibles: `DB_URL`, `DB_USER`, `DB_PASSWORD`, `SERVER_PORT` y, en `usuarios`, `JWT_SECRET`.
En `pedidos`, `SQS_QUEUE_URL` activa la publicación en SQS (si está vacía, queda desactivada).

### Compilar y probar

```bash
cd usuarios            # o productos, pedidos, pagos, envios
./mvnw clean package   # compila, ejecuta los tests (con H2 en memoria) y genera el .jar
```

## Docker Swarm

Clúster de 1 manager y 2 workers, con secretos, réplicas, healthchecks y actualizaciones
sin corte. Guía completa, incluida la forma de **agregar nodos manager y worker**, en
[`swarm/README.md`](swarm/README.md).

```bash
bash swarm/scripts/01-crear-cluster.sh
bash swarm/scripts/02-publicar-imagenes.sh
bash swarm/scripts/03-desplegar.sh
```

## Nube (AWS)

Los recursos se crean con scripts idempotentes (se pueden repetir sin duplicar nada):

| Orden | Script | Qué crea |
|---|---|---|
| 1 | `aws/scripts/01-crear-cola.sh` | Cola SQS `tienda-pedidos` |
| 2 | `lambda/deploy.sh` | Lambda `tienda-procesar-pedido`, tópico SNS y conexión con la cola |
| 3 | `aws/scripts/02-crear-ecr.sh` | Repositorios de imágenes (ECR) |
| 4 | `aws/scripts/03-publicar-imagenes-ecr.sh` | Construye y sube las imágenes |
| 5 | `aws/scripts/04-crear-ec2.sh` | Instancia EC2 con Docker e IP elástica |
| 6 | `aws/scripts/05-desplegar-ec2.sh` | Despliega el sistema en la EC2 |
| 7 | `aws/scripts/06-crear-api-gateway.sh` | API Gateway con API key |

Las credenciales y secretos no están en el repositorio: la contraseña de MySQL, el secreto
del JWT y el secreto del gateway viven en **AWS Systems Manager Parameter Store** y la
instancia los lee con su rol.

**Protección del backend:** el API Gateway exige una API key (`x-api-key`) y agrega una
cabecera secreta. nginx, que es la única puerta de entrada de la EC2, rechaza con 403
cualquier petición que no la traiga. Los microservicios no publican puertos a internet.

```bash
curl -i  $URL/api/productos                       # 403: falta la API key
curl -s -H "x-api-key: $CLAVE" $URL/api/productos # 200
```

Función serverless: ver [`lambda/README.md`](lambda/README.md).

## Pipeline de CI/CD

`.github/workflows/ci-cd.yml` automatiza todo el flujo sin intervención manual:

1. **Build y test** de cada microservicio (en paralelo) con MySQL temporal.
2. **Provisionar nube y desplegar:** credenciales de AWS, cola SQS, repositorios ECR, función
   Lambda, construcción y publicación de imágenes (etiqueta = SHA del commit), acceso SSH
   temporal para el runner, despliegue en la EC2, cierre del acceso, API Gateway y
   prueba de humo a través del gateway.

Cuándo se ejecuta: en cada *pull request* hacia `develop` solo corre la etapa de build y test;
en cada *push* a `develop` o `main` corre el flujo completo (incluye la nube).

Secretos de GitHub necesarios (Settings → Secrets and variables → Actions):

| Secreto | Contenido |
|---|---|
| `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN` | Credenciales temporales de AWS Academy (se renuevan en cada sesión del laboratorio) |
| `EC2_SSH_KEY` | Contenido completo del archivo `.pem` del laboratorio |
| `NOTIFY_EMAIL` | Correo que recibe las notificaciones de SNS |

## Flujo de trabajo con Git

- `main`: versión estable y entregada. `develop`: integración.
- `feature/...`, `fix/...`, `docs/...`: una rama por tarea, integrada con Pull Request.
- Commits con el formato `tipo(ámbito): descripción` (`feat`, `fix`, `build`, `ci`, `test`, `docs`, `chore`).

## Decisiones técnicas

- **Una base de datos por microservicio** y servicios con una sola responsabilidad: se escalan de forma independiente.
- **Imágenes multi-stage** con usuario sin privilegios y `HEALTHCHECK`: livianas, más seguras y monitoreables.
- **Docker secrets** en Swarm y **Parameter Store** en AWS: ninguna contraseña en el código.
- **Cola SQS + Lambda:** el pedido se confirma de inmediato y la notificación se procesa de forma asíncrona y reintentable.
- **API Gateway + nginx con cabecera secreta:** el backend no se puede usar sin pasar por el gateway.

## Limitaciones conocidas

- Las contraseñas de usuarios se guardan en texto plano (pendiente: BCrypt y respuestas sin el campo `password`).
- MySQL corre como un contenedor de una sola réplica con almacenamiento local; en producción se usaría una base administrada (Amazon RDS), como en el diagrama de arquitectura.
- Si el pago se registra pero la notificación falla, la Lambda reintenta el mensaje y el pago podría duplicarse (falta una clave de idempotencia).
- El entorno de AWS Academy usa credenciales temporales y un único rol (`LabRole`).
- Al reiniciar el laboratorio, AWS Academy puede dejar desactivada la conexión cola → Lambda; `lambda/deploy.sh` la vuelve a activar en cada ejecución del pipeline.

## Autores

- Gabriela Herrera (@gabherrera22)
