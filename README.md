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
- Elixir 1.14+ y Erlang 25+ (solo para desarrollo local)
- PostgreSQL 15+ (solo para desarrollo local)
- Docker y Docker Compose (para Docker)

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix
