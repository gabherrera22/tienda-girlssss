-- Se ejecuta una sola vez, al crear el volumen de MySQL por primera vez.
-- Crea las bases vacias; las tablas las genera Hibernate (ddl-auto=update).
CREATE DATABASE IF NOT EXISTS usuarios_db  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS productos_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS pedidos_db   CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS pagos_db     CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS envios_db    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

GRANT ALL PRIVILEGES ON usuarios_db.*  TO 'tienda'@'%';
GRANT ALL PRIVILEGES ON productos_db.* TO 'tienda'@'%';
GRANT ALL PRIVILEGES ON pedidos_db.*   TO 'tienda'@'%';
GRANT ALL PRIVILEGES ON pagos_db.*     TO 'tienda'@'%';
GRANT ALL PRIVILEGES ON envios_db.*    TO 'tienda'@'%';
FLUSH PRIVILEGES;
