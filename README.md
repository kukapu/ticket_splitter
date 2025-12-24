# TicketSplitter

Aplicación web para dividir cuentas de restaurantes entre múltiples personas usando análisis de imágenes con IA.

## 🚀 Inicio Rápido

### Opción 1: Docker (Recomendado)

```bash
# Configuración automática
./setup-docker.sh

# O manualmente:
cp env.dev.example .env.dev
# Edita .env.dev y añade tu OPENROUTER_API_KEY

# Inicia Docker
docker compose -f docker-compose.dev.yml up -d
```

📖 **Guía completa:** [DOCKER_QUICKSTART.md](DOCKER_QUICKSTART.md)

### Opción 2: Desarrollo Local

```bash
# Configurar variables de entorno
export OPENROUTER_API_KEY="tu_api_key"
export OPENROUTER_MODEL="openai/gpt-4o"

# Instalar dependencias
mix setup

# Iniciar servidor
mix phx.server
```

Visita [`localhost:4000`](http://localhost:4000) desde tu navegador.

## 📋 Requisitos

- **OpenRouter API Key** (obligatorio) - [Obtén una aquí](https://openrouter.ai/keys)
- **MinIO/S3** (para almacenamiento de imágenes)
- Elixir 1.14+ y Erlang 25+ (solo para desarrollo local)
- PostgreSQL 15+ (solo para desarrollo local)
- Docker y Docker Compose (para Docker)

## 🗄️ Configuración de MinIO/S3

### Desarrollo Local

Para desarrollo local, la aplicación usa valores por defecto que funcionan con MinIO local:

```bash
# Estos son los valores por defecto (NO necesitas configurarlos)
MINIO_ACCESS_KEY=minioadmin
MINIO_SECRET_KEY=minioadmin
MINIO_SCHEME=http
MINIO_HOST=localhost
MINIO_PORT=9000
MINIO_REGION=us-east-1
MINIO_BUCKET=ticket-splitter
MINIO_PUBLIC_URL=http://localhost:9000/ticket-splitter
```

**Iniciar MinIO con Docker:**

```bash
docker run -p 9000:9000 -p 9001:9001 \
  --name minio \
  -e "MINIO_ROOT_USER=minioadmin" \
  -e "MINIO_ROOT_PASSWORD=minioadmin" \
  -v ~/minio/data:/data \
  quay.io/minio/minio server /data --console-address ":9001"
```

Accede a la consola en `http://localhost:9001` y crea el bucket `ticket-splitter`.

### Producción (Dokploy)

Configura estas variables de entorno en Dokploy:

```bash
MINIO_ACCESS_KEY=tu_access_key_real
MINIO_SECRET_KEY=tu_secret_key_real
MINIO_SCHEME=https
MINIO_HOST=s3.tudominio.com
MINIO_PORT=443
MINIO_REGION=us-east-1
MINIO_BUCKET=ticket-splitter
MINIO_PUBLIC_URL=https://s3.tudominio.com/ticket-splitter
```

**Carpetas automáticas:**
- `tickets/` - Imágenes procesadas correctamente
- `tickets-error/` - Imágenes que fallaron (para análisis)

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix

