// Service Worker para Ticket Splitter PWA
// Versión del caché - cambiar esto para forzar actualización
const CACHE_VERSION = 'v1.0.1';
const STATIC_CACHE = `ticket-splitter-static-${CACHE_VERSION}`;
const DYNAMIC_CACHE = `ticket-splitter-dynamic-${CACHE_VERSION}`;
const OFFLINE_PAGE = '/offline.html';

// URLs críticas que SIEMPRE deben estar en caché
const CRITICAL_ASSETS = [
  '/',
  '/offline.html',
  '/manifest.json',
  '/images/icon-192x192.png',
  '/images/icon-512x512.png',
  '/images/logo-color.svg',
  '/favicon.ico'
];

// Patrones que NUNCA deben cachearse (LiveView, WebSockets, API)
const NEVER_CACHE_PATTERNS = [
  '/live',
  '/phoenix',
  '/phx',
  'websocket',
  '/api/live'
];

// ============= EVENTO: INSTALL =============
// Se ejecuta cuando se instala el service worker por primera vez
self.addEventListener('install', (event) => {
  console.log('[SW] Installing Service Worker version:', CACHE_VERSION);

  event.waitUntil(
    caches.open(STATIC_CACHE)
      .then((cache) => {
        console.log('[SW] Precaching critical assets');
        return cache.addAll(CRITICAL_ASSETS);
      })
      .then(() => {
        // Activar inmediatamente sin esperar a que se cierren otras pestañas
        return self.skipWaiting();
      })
      .catch((error) => {
        console.error('[SW] Installation failed:', error);
      })
  );
});

// ============= EVENTO: ACTIVATE =============
// Se ejecuta cuando el service worker se activa
self.addEventListener('activate', (event) => {
  console.log('[SW] Activating Service Worker version:', CACHE_VERSION);

  event.waitUntil(
    caches.keys()
      .then((cacheNames) => {
        return Promise.all(
          cacheNames
            .filter((cacheName) => {
              // Eliminar caches antiguos que no coincidan con la versión actual
              return cacheName.startsWith('ticket-splitter-') &&
                cacheName !== STATIC_CACHE &&
                cacheName !== DYNAMIC_CACHE;
            })
            .map((cacheName) => {
              console.log('[SW] Deleting old cache:', cacheName);
              return caches.delete(cacheName);
            })
        );
      })
      .then(() => {
        // Tomar control de todas las páginas inmediatamente
        return self.clients.claim();
      })
  );
});

// ============= EVENTO: FETCH =============
// Intercepta cada request que hace la aplicación
self.addEventListener('fetch', (event) => {
  const { request } = event;
  const url = new URL(request.url);

  // Solo procesar requests HTTP/HTTPS del mismo origen
  if (!url.protocol.startsWith('http')) {
    return;
  }

  // NUNCA cachear LiveView, WebSockets o patrones excluidos
  if (shouldNeverCache(url)) {
    return; // Dejar que la red maneje estos requests normalmente
  }

  // Determinar estrategia según tipo de contenido
  if (isStaticAsset(url)) {
    // Assets estáticos: Cache First con fallback a red
    event.respondWith(cacheFirstStrategy(request));
  } else if (isNavigationRequest(request)) {
    // Navegación (páginas HTML): Network First con fallback a offline
    event.respondWith(networkFirstForNavigation(request));
  } else {
    // Otros recursos: Network First con caché dinámico
    event.respondWith(networkFirstStrategy(request));
  }
});

// ============= ESTRATEGIAS DE CACHING =============

/**
 * Cache First, Network Fallback
 * Ideal para: Assets estáticos (CSS, JS, imágenes, fuentes)
 */
async function cacheFirstStrategy(request) {
  try {
    // Primero buscar en caché
    const cachedResponse = await caches.match(request);
    if (cachedResponse) {
      return cachedResponse;
    }

    // Si no está en caché, traer de la red
    const networkResponse = await fetch(request);

    // Guardar en caché si es exitoso
    if (networkResponse.ok) {
      const cache = await caches.open(STATIC_CACHE);
      cache.put(request, networkResponse.clone());
    }

    return networkResponse;
  } catch (error) {
    console.error('[SW] Cache first strategy failed:', error);

    // Si es imagen, retornar placeholder SVG
    if (request.destination === 'image') {
      return createPlaceholderImage();
    }

    // Para otros, intentar página offline
    return caches.match(OFFLINE_PAGE) || createOfflineResponse();
  }
}

/**
 * Network First, Cache Fallback
 * Ideal para: Contenido dinámico, API calls
 */
async function networkFirstStrategy(request) {
  try {
    const networkResponse = await fetch(request);

    // Guardar respuesta exitosa en caché dinámico (solo GET)
    if (networkResponse.ok && request.method === 'GET') {
      const cache = await caches.open(DYNAMIC_CACHE);
      cache.put(request, networkResponse.clone());
    }

    return networkResponse;
  } catch (error) {
    console.log('[SW] Network failed, trying cache:', request.url);

    // Fallback al caché
    const cachedResponse = await caches.match(request);
    if (cachedResponse) {
      return cachedResponse;
    }

    return createOfflineResponse();
  }
}

/**
 * Network First para navegación con fallback a página offline
 * Ideal para: Páginas HTML
 */
async function networkFirstForNavigation(request) {
  try {
    const networkResponse = await fetch(request);

    // Guardar página en caché si es exitosa
    if (networkResponse.ok) {
      const cache = await caches.open(DYNAMIC_CACHE);
      cache.put(request, networkResponse.clone());
    }

    return networkResponse;
  } catch (error) {
    console.log('[SW] Navigation failed, trying cache/offline:', request.url);

    // Intentar obtener de caché
    const cachedResponse = await caches.match(request);
    if (cachedResponse) {
      return cachedResponse;
    }

    // Último recurso: página offline
    const offlinePage = await caches.match(OFFLINE_PAGE);
    if (offlinePage) {
      return offlinePage;
    }

    return createOfflineResponse();
  }
}

// ============= FUNCIONES AUXILIARES =============

/**
 * Determina si una URL nunca debe cachearse
 */
function shouldNeverCache(url) {
  const pathname = url.pathname;
  return NEVER_CACHE_PATTERNS.some(pattern =>
    pathname.includes(pattern) || url.href.includes(pattern)
  );
}

/**
 * Determina si es un asset estático
 */
function isStaticAsset(url) {
  return /\.(js|css|png|jpg|jpeg|gif|svg|ico|woff|woff2|ttf|eot|webp)$/i.test(url.pathname) ||
    url.pathname.startsWith('/assets/');
}

/**
 * Determina si es una request de navegación (página HTML)
 */
function isNavigationRequest(request) {
  return request.mode === 'navigate' ||
    (request.method === 'GET' && request.headers.get('accept')?.includes('text/html'));
}

/**
 * Crea imagen placeholder SVG cuando no hay conexión
 */
function createPlaceholderImage() {
  const svg = `
    <svg xmlns="http://www.w3.org/2000/svg" width="200" height="200" viewBox="0 0 200 200">
      <rect fill="#1f2937" width="200" height="200"/>
      <text x="100" y="100" text-anchor="middle" dy=".35em" fill="#9ca3af" font-family="system-ui" font-size="14">
        Sin conexión
      </text>
    </svg>
  `.trim();

  return new Response(svg, {
    headers: { 'Content-Type': 'image/svg+xml' }
  });
}

/**
 * Crea respuesta offline básica cuando todo falla
 */
function createOfflineResponse() {
  return new Response(
    `<!DOCTYPE html>
    <html lang="es">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Sin conexión - Ticket Splitter</title>
      <style>
        body {
          font-family: system-ui, -apple-system, sans-serif;
          display: flex;
          align-items: center;
          justify-content: center;
          min-height: 100vh;
          margin: 0;
          background: linear-gradient(135deg, #13171C 0%, #1f2937 100%);
          color: white;
        }
        .container {
          text-align: center;
          padding: 2rem;
        }
        h1 { font-size: 1.5rem; margin-bottom: 0.5rem; }
        p { color: #9ca3af; }
        button {
          margin-top: 1rem;
          padding: 0.75rem 1.5rem;
          background: #7B61FF;
          color: white;
          border: none;
          border-radius: 0.5rem;
          font-size: 1rem;
          cursor: pointer;
        }
        button:hover { background: #6B51EF; }
      </style>
    </head>
    <body>
      <div class="container">
        <h1>📱 Sin conexión</h1>
        <p>No se puede conectar al servidor.</p>
        <button onclick="window.location.reload()">Reintentar</button>
      </div>
    </body>
    </html>`,
    {
      status: 503,
      headers: { 'Content-Type': 'text/html; charset=utf-8' }
    }
  );
}

// ============= MENSAJES DESDE EL CLIENTE =============
self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }

  if (event.data && event.data.type === 'GET_VERSION') {
    event.ports[0]?.postMessage({ version: CACHE_VERSION });
  }

  if (event.data && event.data.type === 'CLEAR_CACHE') {
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cacheName) => caches.delete(cacheName))
      );
    }).then(() => {
      event.ports[0]?.postMessage({ cleared: true });
    });
  }
});

console.log('[SW] Service Worker script loaded, version:', CACHE_VERSION);
