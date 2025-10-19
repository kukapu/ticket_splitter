-- Inicialización de base de datos para desarrollo
-- Este archivo se ejecuta cuando el contenedor de PostgreSQL se inicia por primera vez

-- Crear extensión UUID si es necesario
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Crear extensión para búsqueda de texto completo si es necesario
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Configuraciones adicionales para desarrollo
ALTER SYSTEM SET timezone = 'UTC';