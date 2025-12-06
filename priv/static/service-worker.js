// Service Worker para Ticket Splitter PWA
// Versión del caché - cambiar para forzar actualización
const CACHE_VERSION = 'v1';
const STATIC_CACHE = `app-shell-${CACHE_VERSION}`;
const DYNAMIC_CACHE = `dynamic-${CACHE_VERSION}`;
const OFFLINE_PAGE = '/offline.html';

// URLs que SIEMPRE deben estar en caché (críticas)
const CRITICAL_ASSETS = [
  '/',
  '/offline.html',
  '/manifest.json'
];

// Archivos a no cachear (LiveView, WebSockets, etc.)
const NEVER_CACHE = [
  '/live',
  '/phx',
  '/phx_join',
  '/phx_leave',
  '/phoenix/live_reload'
];

// ============= EVENTO: INSTALL =============
// Se ejecuta cuando se instala el service worker por primera vez
self.addEventListener('install', (event) => {
  console.log('[SW] Installing Service Worker...', CACHE_VERSION);

  event.waitUntil(
    caches.open(STATIC_CACHE)
      .then((cache) => {
        console.log('[SW] Precaching static assets');
        return cache.addAll(CRITICAL_ASSETS);
      })
      .then(() => {
        // Forzar activación inmediata
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
  console.log('[SW] Activating Service Worker...', CACHE_VERSION);

  event.waitUntil(
    caches.keys()
      .then((cacheNames) => {
        return Promise.all(
          cacheNames
            .filter((cacheName) => {
              // Eliminar caches antiguos
              return cacheName !== STATIC_CACHE && cacheName !== DYNAMIC_CACHE;
            })
            .map((cacheName) => {
              console.log('[SW] Deleting old cache:', cacheName);
              return caches.delete(cacheName);
            })
        );
      })
      .then(() => {
        // Tomar control de páginas inmediatamente
        return self.clients.claim();
      })
  );
});

// ============= EVENTO: FETCH =============
// Se intercepta cada request que hace la aplicación
self.addEventListener('fetch', (event) => {
  const { request } = event;
  const url = new URL(request.url);

  // No cachear algunos tipos de requests
  if (shouldNotCache(url)) {
    event.respondWith(fetch(request));
    return;
  }

  // Determinar estrategia según tipo de contenido
  if (isStaticAsset(url)) {
    // Cache first, network fallback
    event.respondWith(cacheFirstStrategy(request));
  } else if (isHTMLPage(request)) {
    // Network first para páginas HTML
    event.respondWith(networkFirstStrategy(request));
  } else {
    // Network first para todo lo demás
    event.respondWith(networkFirstStrategy(request));
  }
});

// ============= ESTRATEGIAS DE CACHING =============

// Estrategia 1: Cache First, Network Fallback
// Ideal para: Assets estáticos, imágenes, CSS, JS
async function cacheFirstStrategy(request) {
  try {
    // Primero buscar en caché
    const cachedResponse = await caches.match(request);
    if (cachedResponse) {
      console.log('[SW] Serving from cache:', request.url);
      return cachedResponse;
    }

    // Si no está en caché, traer de la red
    const networkResponse = await fetch(request);

    // Guardar en caché para futuro (solo si es exitoso y GET)
    if (networkResponse.ok && request.method === 'GET' && !isExcludedFromCache(request.url)) {
      const cache = await caches.open(DYNAMIC_CACHE);
      cache.put(request, networkResponse.clone());
    }

    return networkResponse;
  } catch (error) {
    console.error('[SW] Cache first strategy failed:', error);

    // Si es imagen, retornar placeholder
    if (request.destination === 'image') {
      return createPlaceholderResponse();
    }

    // Para todo lo demás, página offline
    return caches.match(OFFLINE_PAGE) 
      || new Response('Offline', { status: 503, headers: { 'Content-Type': 'text/html' } });
  }
}

// Estrategia 2: Network First, Cache Fallback
// Ideal para: API calls, contenido dinámico, páginas HTML
async function networkFirstStrategy(request) {
  const cache = await caches.open(DYNAMIC_CACHE);

  try {
    const networkResponse = await fetch(request);

    // Guardar respuesta exitosa en caché (solo GET)
    if (networkResponse.ok && request.method === 'GET' && !isExcludedFromCache(request.url)) {
      cache.put(request, networkResponse.clone());
    }

    return networkResponse;
  } catch (error) {
    console.log('[SW] Network request failed:', request.url, error);

    // Fallback al caché
    const cachedResponse = await cache.match(request);
    if (cachedResponse) {
      console.log('[SW] Serving from cache (network failed):', request.url);
      return cachedResponse;
    }

    // Si es una página HTML y no hay caché, mostrar offline
    if (request.mode === 'navigate') {
      return caches.match(OFFLINE_PAGE) 
        || new Response('Offline', { status: 503, headers: { 'Content-Type': 'text/html' } });
    }

    // Para otros recursos, retornar error
    return new Response('Offline', { status: 503 });
  }
}

// ============= FUNCIONES AUXILIARES =============

function shouldNotCache(url) {
  // No cachear WebSockets, live view, etc.
  if (url.protocol !== 'http:' && url.protocol !== 'https:') {
    return true;
  }

  // No cachear rutas de LiveView
  return NEVER_CACHE.some(path => url.pathname.includes(path));
}

function isStaticAsset(url) {
  // Assets estáticos con hash (CSS, JS con hash)
  if (url.pathname.startsWith('/assets/')) {
    return true;
  }

  // Otros assets estáticos
  return /\.(js|css|png|jpg|jpeg|gif|svg|woff|woff2|ttf|eot|ico|webp)$/i.test(url.pathname);
}

function isHTMLPage(request) {
  return request.mode === 'navigate' || 
         (request.headers.get('accept') && request.headers.get('accept').includes('text/html'));
}

function isExcludedFromCache(url) {
  // URLs que no queremos cachear aunque se carguen exitosamente
  const excluded = [
    '/live',
    '/phx',
    '/api/ws',
    '/api/stream'
  ];
  return excluded.some(path => url.includes(path));
}

function createPlaceholderResponse() {
  // Retornar imagen placeholder SVG cuando no hay conexión
  return new Response(
    `<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
       <rect fill="#e5e7eb" width="100" height="100"/>
       <text x="50%" y="50%" text-anchor="middle" dominant-baseline="middle" fill="#9ca3af" font-size="12">Sin conexión</text>
     </svg>`,
    {
      headers: { 'Content-Type': 'image/svg+xml' }
    }
  );
}

// ============= MENSAJES DESDE EL CLIENTE =============
self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }

  if (event.data && event.data.type === 'GET_SW_VERSION') {
    event.ports[0].postMessage({ version: CACHE_VERSION });
  }
});

console.log('[SW] Service Worker script loaded', CACHE_VERSION);

