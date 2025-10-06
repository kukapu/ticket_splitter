# Ticket Splitter - Configuración para análisis de imágenes con OpenRouter

## Configuración requerida

### 1. Variables de entorno

Necesitas configurar las siguientes variables de entorno:

```bash
# API Key de OpenRouter (REQUERIDO)
export OPENROUTER_API_KEY="your_openrouter_api_key_here"

# Modelo a usar (OPCIONAL - por defecto: openai/gpt-4o)
export OPENROUTER_MODEL="openai/gpt-4o"

# Prompt personalizado (OPCIONAL)
export OPENROUTER_PROMPT="Analiza esta imagen de un ticket o recibo. Extrae todos los elementos de la compra, precios, total, fecha, establecimiento y cualquier otra información relevante. Responde en formato JSON estructurado."
```

### 2. Obtener API Key de OpenRouter

1. Ve a [OpenRouter.ai](https://openrouter.ai/)
2. Crea una cuenta o inicia sesión
3. Ve a la sección de API Keys
4. Genera una nueva API Key
5. Configura el crédito/billing si es necesario

### 3. Modelos disponibles

Algunos modelos recomendados para análisis de imágenes:

- `openai/gpt-4o` (recomendado, mejor calidad)
- `openai/gpt-4-turbo`
- `google/gemini-pro-vision`
- `anthropic/claude-3-sonnet`

### 4. Personalizar el prompt

Puedes personalizar el prompt para obtener diferentes tipos de análisis:

```bash
# Para análisis de tickets/recibos estructurado
export OPENROUTER_PROMPT="Analiza esta imagen de un ticket o recibo. Extrae todos los elementos de la compra, precios, total, fecha, establecimiento y cualquier otra información relevante. Responde en formato JSON estructurado con los siguientes campos: establecimiento, fecha, items (array con nombre y precio), subtotal, impuestos, total."

# Para descripción general
export OPENROUTER_PROMPT="Describe detalladamente lo que ves en esta imagen."

# Para análisis de gastos
export OPENROUTER_PROMPT="Analiza este recibo de compra y categoriza los gastos. Identifica: comercio, fecha, método de pago, productos comprados con precios, total gastado. Responde en JSON."
```

## Uso

1. Configura las variables de entorno
2. Inicia la aplicación: `mix phx.server`
3. Abre http://localhost:4000
4. Sube una imagen de un ticket usando:
   - El botón "Seleccionar imagen" (galería)
   - El botón "Tomar foto" (solo en móviles)
   - Drag & drop de la imagen

La aplicación procesará la imagen y mostrará el resultado del análisis de OpenRouter.

## Funcionalidades

- ✅ Carga de imágenes desde galería
- ✅ Toma de fotos desde cámara (móvil)
- ✅ Drag & drop de imágenes
- ✅ Validación de tipos de archivo (JPG, PNG, WEBP)
- ✅ Límite de tamaño (10MB)
- ✅ Integración con OpenRouter API
- ✅ Visualización de resultados en JSON
- ✅ Manejo de errores
- ✅ Interface responsiva para móvil y desktop

## Formatos soportados

- JPG/JPEG
- PNG
- WEBP
- Tamaño máximo: 10MB

## Troubleshooting

### Error: "API key no configurada"
- Verifica que `OPENROUTER_API_KEY` esté configurada correctamente
- Reinicia el servidor después de configurar la variable

### Error de HTTP 401
- Verifica que tu API key sea válida
- Comprueba que tienes créditos disponibles en OpenRouter

### Error de HTTP 429
- Has alcanzado el límite de rate limit
- Espera unos minutos antes de intentar de nuevo

### La imagen no se procesa
- Verifica que el formato sea soportado
- Comprueba que el tamaño no exceda 10MB
- Revisa los logs de la aplicación para más detalles