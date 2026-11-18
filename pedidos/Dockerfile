# ---------- Etapa 1: compilar ----------
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /app

# Se copia primero solo el pom para aprovechar la caché de capas:
# si no cambian las dependencias, Docker no las vuelve a descargar.
COPY pom.xml .
RUN mvn -B -q dependency:go-offline

COPY src ./src
# Los tests se ejecutan en el pipeline de CI, no al construir la imagen.
RUN mvn -B -q clean package -DskipTests

# ---------- Etapa 2: ejecutar ----------
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app

# Usuario sin privilegios: el contenedor no corre como root.
RUN addgroup -S app && adduser -S app -G app

COPY --from=build /app/target/*.jar app.jar
USER app

EXPOSE 8083

HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD wget -qO- http://localhost:8083/actuator/health || exit 1

ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75", "-jar", "app.jar"]