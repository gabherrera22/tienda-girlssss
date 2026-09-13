-- ==========================================
-- 1. BASE DE DATOS: MS USUARIOS Y PERFILES
-- ==========================================
CREATE DATABASE IF NOT EXISTS usuarios_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE usuarios_db;

CREATE TABLE roles (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE usuarios (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    cognito_sub VARCHAR(255) UNIQUE COMMENT 'ID único de referencia desde Amazon Cognito',
    email VARCHAR(150) NOT NULL UNIQUE,
    nombre VARCHAR(100) NOT NULL,
    apellido VARCHAR(100) NOT NULL,
    telefono VARCHAR(20),
    fecha_creacion DATETIME DEFAULT CURRENT_TIMESTAMP,
    activo BOOLEAN DEFAULT TRUE
);

CREATE TABLE usuario_roles (
    usuario_id BIGINT NOT NULL,
    rol_id BIGINT NOT NULL,
    PRIMARY KEY (usuario_id, rol_id),
    FOREIGN KEY (usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE,
    FOREIGN KEY (rol_id) REFERENCES roles(id) ON DELETE CASCADE
);

-- ==========================================
-- 2. BASE DE DATOS: MS PRODUCTOS E INVENTARIO
-- ==========================================
CREATE DATABASE IF NOT EXISTS productos_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE productos_db;

CREATE TABLE categorias (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL UNIQUE,
    descripcion TEXT
);

CREATE TABLE productos (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    categoria_id BIGINT,
    sku VARCHAR(50) NOT NULL UNIQUE,
    nombre VARCHAR(150) NOT NULL,
    descripcion TEXT,
    precio DECIMAL(10, 2) NOT NULL,
    stock_actual INT NOT NULL DEFAULT 0,
    imagen_url VARCHAR(255),
    activo BOOLEAN DEFAULT TRUE,
    fecha_creacion DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (categoria_id) REFERENCES categorias(id) ON DELETE SET NULL
);

-- ==========================================
-- 3. BASE DE DATOS: MS CARRITO Y PEDIDOS
-- ==========================================
CREATE DATABASE IF NOT EXISTS pedidos_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE pedidos_db;

CREATE TABLE carritos (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    usuario_id BIGINT NOT NULL COMMENT 'ID de referencia del MS Usuarios',
    fecha_actualizacion DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE items_carrito (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    carrito_id BIGINT NOT NULL,
    producto_id BIGINT NOT NULL COMMENT 'ID de referencia del MS Productos',
    cantidad INT NOT NULL DEFAULT 1,
    FOREIGN KEY (carrito_id) REFERENCES carritos(id) ON DELETE CASCADE
);

CREATE TABLE pedidos (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    usuario_id BIGINT NOT NULL COMMENT 'ID del usuario comprador',
    monto_total DECIMAL(10, 2) NOT NULL,
    estado VARCHAR(30) NOT NULL DEFAULT 'PENDIENTE' COMMENT 'PENDIENTE, PAGADO, CANCELADO, ENVIADO',
    fecha_creacion DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE detalles_pedido (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    pedido_id BIGINT NOT NULL,
    producto_id BIGINT NOT NULL,
    cantidad INT NOT NULL,
    precio_unitario DECIMAL(10, 2) NOT NULL,
    FOREIGN KEY (pedido_id) REFERENCES pedidos(id) ON DELETE CASCADE
);

-- ==========================================
-- 4. BASE DE DATOS: MS PAGOS
-- ==========================================
CREATE DATABASE IF NOT EXISTS pagos_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE pagos_db;

CREATE TABLE pagos (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    pedido_id BIGINT NOT NULL COMMENT 'ID de referencia del MS Pedidos',
    monto DECIMAL(10, 2) NOT NULL,
    metodo_pago VARCHAR(50) NOT NULL COMMENT 'TARJETA, TRANSFERENCIA, COGNITO_PAY, ETC',
    estado VARCHAR(30) NOT NULL DEFAULT 'PROCESANDO' COMMENT 'PROCESANDO, APROBADO, RECHAZADO',
    transaccion_id VARCHAR(100) UNIQUE,
    fecha_pago DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- ==========================================
-- 5. BASE DE DATOS: MS ENVÍOS
-- ==========================================
CREATE DATABASE IF NOT EXISTS envios_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE envios_db;

CREATE TABLE envios (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    pedido_id BIGINT NOT NULL COMMENT 'ID de referencia del MS Pedidos',
    direccion_despacho TEXT NOT NULL,
    ciudad VARCHAR(100) NOT NULL,
    codigo_postal VARCHAR(20),
    empresa_transporte VARCHAR(100) COMMENT 'Nombre de la API/Empresa externa',
    codigo_seguimiento VARCHAR(100),
    estado VARCHAR(30) NOT NULL DEFAULT 'PREPARANDO' COMMENT 'PREPARANDO, EN_TRANSITO, ENTREGADO',
    fecha_creacion DATETIME DEFAULT CURRENT_TIMESTAMP,
    fecha_entrega DATETIME
);