# Guía de Despliegue en Dokploy

Esta guía te ayudará a desplegar TicketSplitter en tu VPS usando Dokploy con GitHub Actions.

## Arquitectura del Despliegue

```
GitHub (push a master)
    ↓
GitHub Actions (build Docker image)
    ↓
GitHub Container Registry (ghcr.io)
    ↓
Webhook a Dokploy
    ↓
Dokploy (pull image y deploy)
```

## Pre-requisitos

1. VPS con Dokploy instalado
2. Base de datos PostgreSQL creada en Dokploy
3. Repositorio GitHub con el código
4. Dominio configurado apuntando al VPS

## Configuración Paso a Paso

### 1. Configurar GitHub Actions

El workflow ya está configurado en `.github/workflows/deploy.yml`. Solo necesitas:

1. **Agregar el secreto del webhook de Dokploy:**
   - Ve a tu repositorio en GitHub
   - Settings → Secrets and variables → Actions
   - Click en "New repository secret"
   - Nombre: `DOKPLOY_WEBHOOK_URL`
   - Valor: La URL del webhook que Dokploy te proporcionó

### 2. Configurar Variables de Entorno en Dokploy

En Dokploy, en la sección de Environment Variables de tu aplicación, configura:

#### Variables Requeridas:

```bash
# OpenRouter API Key (obtén una en https://openrouter.ai/keys)
OPENROUTER_API_KEY=sk-or-v1-xxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# Secret Key Base (genera uno con: mix phx.gen.secret)
SECRET_KEY_BASE=genera_uno_nuevo_con_mix_phx_gen_secret_64_caracteres_minimo

# Database URL (ajusta según tu configuración de Dokploy)
DATABASE_URL=postgresql://usuario:contraseña@nombre-servicio-postgres:5432/nombre_base_datos

# Dominio de tu aplicación
PHX_HOST=tu-dominio.com

# Habilitar servidor Phoenix
PHX_SERVER=true

# Puerto
PORT=4000
```

#### Variables Opcionales:

```bash
# Modelo de OpenRouter (por defecto: openai/gpt-4o)
OPENROUTER_MODEL=openai/gpt-4o

# Tamaño del pool de conexiones
POOL_SIZE=10
```

### 3. Configurar Dokploy

1. **Crear una nueva aplicación en Dokploy:**
   - Nombre: `ticket_splitter`
   - Tipo: Docker Compose

2. **Configurar el docker-compose.yml:**
   - Dokploy usará el archivo `compose.yml` del repositorio
   - Este archivo ya está configurado para usar la imagen de GitHub Container Registry

3. **Configurar el webhook:**
   - En la configuración de la aplicación en Dokploy, copia la URL del webhook
   - Añádela como secreto en GitHub (ver paso 1)

4. **Configurar el dominio:**
   - En Dokploy, en la sección de Domains, añade tu dominio
   - Mapea al puerto `4000`

### 4. Proceso de Despliegue

Una vez configurado todo, el despliegue es automático:

1. **Haces push a master:**
   ```bash
   git add .
   git commit -m "tu mensaje"
   git push origin master
   ```

2. **GitHub Actions automáticamente:**
   - Construye la imagen Docker
   - La publica en GitHub Container Registry como `ghcr.io/[tu-usuario]/ticket_splitter:latest`
   - Activa el webhook de Dokploy

3. **Dokploy automáticamente:**
   - Recibe la notificación del webhook
   - Descarga la nueva imagen
   - Ejecuta las migraciones de la base de datos (automáticamente en el entrypoint)
   - Reinicia el contenedor con la nueva versión

## Verificación

### Ver los logs en Dokploy:

En la interfaz de Dokploy, ve a tu aplicación y abre los logs. Deberías ver:
- "Running database migrations..."
- "Starting Phoenix server..."

### Verificar que la aplicación está funcionando:

```bash
curl https://tu-dominio.com
```

## Solución de Problemas

### Error: "lock outdated" con heroicons durante el build con Nixpacks

**Síntoma:** El build falla con el error:
```
* heroicons (https://github.com/tailwindlabs/heroicons.git - v2.2.0)
  lock outdated: the lock is outdated compared to the options in your mix.exs
** (Mix) Can't continue due to errors on dependencies
```

**Causa:** Dokploy está configurado para usar **Nixpacks** para construir la imagen, en lugar de usar el **Dockerfile** del repositorio o la **imagen pre-construida** de GitHub Container Registry.

**Problema con Nixpacks:**
- Nixpacks ejecuta `COPY .` dos veces durante el build
- Esto sobrescribe el `mix.lock` actualizado después de `mix deps.get`
- Causa inconsistencias con dependencias Git como `heroicons`

**Solución 1: Usar imagen pre-construida (RECOMENDADO):**

En Dokploy, configura la aplicación para usar la imagen de GitHub Container Registry:

1. Ve a la configuración de tu aplicación en Dokploy
2. En "Source Type" o "Build Type", selecciona **"External Image"** o **"Docker Image"**
3. Especifica la imagen: `ghcr.io/[tu-usuario]/ticket_splitter:latest`
4. Esto hará que Dokploy descargue la imagen ya construida por GitHub Actions en lugar de construirla

**Solución 2: Usar Dockerfile en lugar de Nixpacks:**

Si prefieres que Dokploy construya la imagen:

1. Ve a la configuración de tu aplicación en Dokploy
2. En "Build Type" o "Builder", cambia de **Nixpacks** a **Dockerfile**
3. Dokploy usará tu `Dockerfile` existente que está optimizado para Elixir y maneja correctamente las dependencias

**Solución 3: Crear nixpacks.toml (alternativa):**

Si debes usar Nixpacks, crea un archivo `nixpacks.toml` en la raíz:
```toml
[phases.setup]
nixPkgs = ["elixir_1_18", "gcc"]

[phases.install]
cmds = [
  "mix local.hex --force",
  "mix local.rebar --force",
  "mix deps.get --only prod",
  "mix deps.compile"
]

[phases.build]
cmds = [
  "mix compile",
  "mix assets.deploy"
]

[start]
cmd = "mix phx.server"
```

### Las migraciones fallan

```bash
# Conéctate a tu VPS y verifica la conexión a la base de datos
docker exec -it ticket_splitter /app/bin/ticket_splitter remote
```

### La imagen no se descarga

1. Verifica que el repositorio de GitHub Container Registry es público o que Dokploy tiene acceso
2. Para hacer el repositorio público:
   - Ve a https://github.com/users/[tu-usuario]/packages/container/ticket_splitter/settings
   - Cambia la visibilidad a "Public"
3. Asegúrate de que la configuración en Dokploy use "External Image" en lugar de construir desde el código fuente

### El webhook no se activa

1. Verifica que el secreto `DOKPLOY_WEBHOOK_URL` está configurado en GitHub
2. Revisa los logs de GitHub Actions para ver si el curl al webhook se ejecutó correctamente
3. Asegúrate de que la URL no tenga espacios en blanco o saltos de línea

## Estructura de Archivos Importantes

```
.
├── .github/
│   └── workflows/
│       └── deploy.yml          # Workflow de GitHub Actions
├── lib/
│   └── ticket_splitter/
│       └── release.ex          # Módulo para ejecutar migraciones
├── compose.yml                 # Docker Compose para Dokploy
├── Dockerfile                  # Dockerfile de producción
├── entrypoint.sh              # Script que ejecuta migraciones y arranca el servidor
└── .env.example               # Ejemplo de variables de entorno
```

## Notas Importantes

1. **SECRET_KEY_BASE:** Asegúrate de generar uno nuevo y seguro con `mix phx.gen.secret`. No uses valores de ejemplo. Esta clave se usa para firmar y encriptar cookies de sesión, tokens CSRF y datos sensibles.

2. **Migraciones:** Se ejecutan automáticamente cada vez que se inicia el contenedor. Esto es seguro ya que Ecto solo ejecuta las migraciones que faltan.

3. **Base de datos:** La base de datos debe estar creada previamente en Dokploy. Las migraciones solo crean las tablas, no la base de datos.

4. **Primer despliegue:** En el primer despliegue, las migraciones crearán todas las tablas necesarias.

5. **GitHub Container Registry:** Las imágenes se publican en `ghcr.io/[tu-usuario]/ticket_splitter:latest`. Asegúrate de que el paquete sea público o configura las credenciales en Dokploy.

6. **Secretos:** NUNCA incluyas secretos reales en archivos de código. Usa siempre las variables de entorno de Dokploy para configurarlos de forma segura.
