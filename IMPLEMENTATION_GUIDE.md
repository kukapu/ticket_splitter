# Ticket Splitter - Guía de Implementación

## 🎉 Implementación Completada

Se ha completado la implementación de todas las funcionalidades solicitadas para la aplicación de división de cuentas.

## 📋 Funcionalidades Implementadas

### ✅ Core Features

1. **Upload de Imágenes**
   - Subir foto del ticket desde galería o cámara (móvil)
   - Validación de formatos (JPG, PNG, WEBP)
   - Límite de tamaño: 10MB

2. **Integración con OpenRouter**
   - Configuración mediante variables de entorno
   - Uso del prompt personalizado de `spliteats_propmt.md`
   - Parseo automático del JSON de respuesta
   - Guardado en base de datos PostgreSQL

3. **Vista del Ticket (`/tickets/:id`)**
   - Lista de todos los productos extraídos
   - Información de unidades y precios
   - Interfaz mobile-first responsiva

4. **Gestión de Participantes**
   - Sin login: nombre guardado en localStorage
   - Asignación automática de colores únicos
   - Modal para solicitar nombre en primera visita
   - Mensaje recordatorio de usar nombres únicos

5. **Asignación de Productos**
   - Click en producto → asignar/desasignar al usuario actual
   - División automática en partes iguales entre asignados
   - Indicadores visuales de quién tiene cada producto
   - Recalculo automático de porcentajes

6. **Platos Comunes**
   - Swipe derecha → marcar/desmarcar como común
   - División automática entre total de participantes
   - Badge visual "COMÚN"

7. **Edición de Porcentajes**
   - Long-press en producto compartido
   - Modal para editar porcentajes personalizados
   - Validación que sumen 100%

8. **Total Personal**
   - Cálculo en tiempo real
   - Muestra el total a pagar por el usuario actual
   - Incluye platos asignados + proporción de platos comunes

9. **Modal de Resumen**
   - Lista de todos los participantes y sus totales
   - Total del ticket
   - Total asignado
   - Pendiente por asignar

10. **Edición de Total de Participantes**
    - Input editable en header
    - Actualización automática de cálculos de platos comunes

## 🗂️ Estructura de Archivos Creados/Modificados

### Migraciones
- `priv/repo/migrations/*_create_tickets.exs`
- `priv/repo/migrations/*_create_products.exs`
- `priv/repo/migrations/*_create_participant_assignments.exs`

### Schemas
- `lib/ticket_splitter/tickets/ticket.ex`
- `lib/ticket_splitter/tickets/product.ex`
- `lib/ticket_splitter/tickets/participant_assignment.ex`

### Contextos
- `lib/ticket_splitter/tickets.ex` - Contexto con funciones CRUD y lógica de negocio

### LiveViews
- `lib/ticket_splitter_web/live/home_live.ex` - Página principal con upload
- `lib/ticket_splitter_web/live/ticket_live.ex` - Vista del ticket y división
- `lib/ticket_splitter_web/live/ticket_live.html.heex` - Template del ticket

### JavaScript
- `assets/js/app.js` - Hooks para localStorage y swipe

### Router
- `lib/ticket_splitter_web/router.ex` - Ruta `/tickets/:id`

### Otros
- `priv/openrouter_prompt.txt` - Prompt para OpenRouter
- `priv/repo/seeds_mock.exs` - Datos de prueba

## 🚀 Cómo Usar

### Configuración Inicial

1. **Configurar PostgreSQL con Docker:**
   ```bash
   docker run --name ticket_splitter_db \
     -e POSTGRES_USER=postgres \
     -e POSTGRES_PASSWORD=postgres \
     -e POSTGRES_DB=ticket_splitter_dev \
     -p 5432:5432 \
     -d postgres:15
   ```

2. **Crear y migrar la base de datos:**
   ```bash
   mix ecto.create
   mix ecto.migrate
   ```

3. **Configurar variables de entorno para OpenRouter:**
   ```bash
   export OPENROUTER_API_KEY="tu_api_key_aqui"
   export OPENROUTER_MODEL="openai/gpt-4o"  # Opcional
   ```

4. **Instalar dependencias de assets:**
   ```bash
   mix assets.setup
   ```

5. **Iniciar el servidor:**
   ```bash
   mix phx.server
   ```

### Usando Mock Data (Sin Base de Datos)

Si quieres probar sin configurar la BD ni OpenRouter:

```bash
mix ecto.create
mix ecto.migrate
mix run priv/repo/seeds_mock.exs
```

Esto creará un ticket de ejemplo que podrás ver en el ID que te muestre el comando.

## 📱 Flujo de Usuario

### Para el que sube el ticket:

1. Ir a `http://localhost:4000`
2. Subir foto del ticket (galería o cámara)
3. Esperar procesamiento de IA
4. Automáticamente redirige a `/tickets/:id`
5. Compartir el enlace con los demás comensales

### Para todos los participantes:

1. Abrir el enlace del ticket
2. Introducir tu nombre (se guarda en localStorage)
3. **Asignar platos personales:** Click en cada plato que comiste
4. **Marcar platos comunes:** Swipe derecha en pan, entrantes, etc.
5. **Ajustar porcentajes:** Si compartes un plato pero no a partes iguales
6. **Editar participantes:** Ajustar el total de personas para platos comunes
7. **Ver resumen:** Click en botón "Info" para ver el desglose completo

## 🎨 Características UX

- **Mobile-First:** Diseñado principalmente para smartphones
- **Sin fricción:** No requiere login ni registro
- **Visual:** Colores únicos por participante
- **Tiempo real:** Cálculos actualizados instantáneamente
- **Swipe gestures:** Interfaz natural para móvil
- **Indicadores visuales:** Badges, colores, iconos

## 🔧 Configuración de OpenRouter

El archivo de configuración `config/dev.exs` ya está preparado:

```elixir
config :ticket_splitter,
  openrouter_api_key: System.get_env("OPENROUTER_API_KEY"),
  openrouter_model: System.get_env("OPENROUTER_MODEL") || "openai/gpt-4o"
```

El prompt se lee automáticamente de `priv/openrouter_prompt.txt`.

## 🐛 Próximos Pasos / Mejoras Futuras

- Agregar tests automatizados
- Implementar compartir link con QR code
- Agregar propinas porcentuales
- Historial de tickets
- Exportar a PDF
- Soporte para múltiples monedas
- PWA para instalación en móvil

## 📊 Modelo de Datos

```
Ticket
  ├── id (binary_id)
  ├── image_url (string)
  ├── products_json (jsonb)
  ├── total_participants (integer)
  └── Products []
        ├── id (binary_id)
        ├── name (string)
        ├── units (integer)
        ├── unit_price (decimal)
        ├── total_price (decimal)
        ├── confidence (decimal)
        ├── is_common (boolean)
        └── ParticipantAssignments []
              ├── id (binary_id)
              ├── participant_name (string)
              ├── percentage (decimal)
              └── assigned_color (string)
```

## 🎯 Decisiones de Diseño

1. **Sin login:** Se usa localStorage para identificación simple
2. **Colores automáticos:** 10 colores predefinidos asignados al entrar
3. **Porcentajes vs ratios:** Se eligió porcentajes por ser más intuitivo
4. **Swipe para comunes:** Interacción natural en móvil sin ocupar espacio
5. **Total participantes editable:** Permite flexibilidad sin rastrear todos los dispositivos
6. **BD relacional:** Permite consultas complejas y mantenimiento de integridad

## ✨ Funcionalidades Extra Implementadas

- Validación de inputs
- Manejo de errores
- Loading states
- Animaciones de transición
- Diseño responsivo desktop/mobile
- Accesibilidad básica
- Feedback visual inmediato

---

¡La aplicación está lista para usar! Solo necesitas configurar PostgreSQL y las credenciales de OpenRouter.
