# Docker Configuration for TicketSplitter

## Overview

This project now includes Docker configurations for both development and production environments with PostgreSQL database support.

## Environment Configurations

### Development Environment (docker-compose.dev.yml)

**Features:**
- ✅ PostgreSQL database with persistent data
- ✅ Hot reloading (disabled in Docker for stability)
- ✅ Database port exposed at 5433
- ✅ Application port at 4000
- ✅ Health checks for database
- ✅ Automatic database creation and migrations

**Usage:**
```bash
# Start development environment
docker compose -f docker-compose.dev.yml up -d

# View logs
docker compose -f docker-compose.dev.yml logs -f app

# Stop development environment
docker compose -f docker-compose.dev.yml down
```

**Access:**
- Application: http://localhost:4000
- Database: localhost:5433 (postgres/postgres)

### Production Environment (docker-compose.yml)

**Features:**
- ✅ Neon PostgreSQL cloud database
- ✅ Optimized multi-stage Dockerfile
- ✅ Environment-based configuration
- ✅ Production-ready optimizations

**Setup:**
1. Copy `.env.example` to `.env`
2. Set your environment variables:
   ```bash
   SECRET_KEY_BASE=your_generated_secret_key
   PHX_HOST=your-domain.com
   OPENROUTER_API_KEY=your_api_key (optional)
   ```

**Usage:**
```bash
# Build and start production
docker compose up -d --build

# View logs
docker compose logs -f app

# Stop production
docker compose down
```

## Database Configuration

### Development Database
- **Type:** PostgreSQL 15-alpine
- **Host:** db (Docker internal name)
- **Database:** ticket_splitter_dev
- **Credentials:** postgres/postgres
- **Persistent Storage:** Yes (via Docker volume)

### Production Database
- **Type:** Neon PostgreSQL
- **Connection:** via DATABASE_URL environment variable
- **SSL Required:** Yes

## Dockerfiles

### Dockerfile (Production)
Multi-stage build optimized for production:
- Builder stage with all build dependencies
- Runtime stage with minimal footprint
- Asset compilation and optimization
- Release generation

### Dockerfile.dev (Development)
Simplified Dockerfile for development:
- All development dependencies included
- Direct code mounting for hot reload
- Development-specific configurations

## Environment Variables

### Development
- `MIX_ENV=dev_docker`
- `DATABASE_URL=postgresql://postgres:postgres@db:5432/ticket_splitter_dev`
- `PORT=4000`
- `SECRET_KEY_BASE=91ZG1WKwd0Yp5Q4KFzGbUHi/+bUaoA9IbmqrY4orfVIpHsWAfrRb63LB14Kyz/OB`

### Production
- `MIX_ENV=prod`
- `DATABASE_URL=postgresql://postgres:neon_key@host/db?sslmode=require`
- `PHX_SERVER=true`
- `SECRET_KEY_BASE=your_production_secret`
- `PHX_HOST=your-domain.com`
- `OPENROUTER_API_KEY=your_api_key` (optional)

## Volumes

### Development
- `postgres_dev_data`: PostgreSQL data persistence
- `app_deps`: Dependencies cache
- `app_build`: Build cache

### Production
- Uses ephemeral storage (stateless containers)

## Troubleshooting

### Common Issues

1. **Port conflicts:**
   - Development DB uses port 5433 (not 5432)
   - Application uses port 4000
   - Ensure no other services are using these ports

2. **Database connection issues:**
   - Wait for database health check before application starts
   - Check docker-compose logs for connection errors

3. **Permission issues:**
   - Docker containers run as non-root user
   - Ensure proper volume permissions

### Useful Commands

```bash
# Check container status
docker compose -f docker-compose.dev.yml ps

# Access application container
docker compose -f docker-compose.dev.yml exec app sh

# Access database
docker compose -f docker-compose.dev.yml exec db psql -U postgres -d ticket_splitter_dev

# Rebuild containers
docker compose -f docker-compose.dev.yml up --build

# Clean up everything
docker compose -f docker-compose.dev.yml down --volumes
```

## Migration from Local Development

If you're migrating from local development:

1. Backup existing local database if needed
2. Start Docker development environment
3. The database will be automatically created and migrated
4. Your application code is mounted directly, so no changes needed

## Production Deployment

For production deployment:

1. Set up Neon PostgreSQL database
2. Configure environment variables
3. Run production containers
4. Set up reverse proxy (nginx/caddy) if needed
5. Configure SSL/TLS
6. Set up monitoring and logging

## Security Notes

- Production database connection uses SSL
- Secrets are managed via environment variables
- Containers run as non-root user
- Live reload is disabled in production
- Database credentials are not exposed in development images