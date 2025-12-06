const CACHE_NAME = 'ticket-splitter-v1';
const ASSETS_TO_CACHE = [
    '/favicon.ico',
    '/robots.txt',
    '/images/logo-color.svg',
    '/images/icon-192x192.png',
    '/images/icon-512x512.png',
    '/manifest.json'
];

self.addEventListener('install', (event) => {
    event.waitUntil(
        caches.open(CACHE_NAME).then((cache) => {
            // Intenta cachear, pero no falles si alguno falla
            return cache.addAll(ASSETS_TO_CACHE).catch(err => {
                console.warn('Algunos recursos no se pudieron cachear:', err);
            });
        })
    );
    self.skipWaiting();
});

self.addEventListener('activate', (event) => {
    event.waitUntil(
        caches.keys().then((cacheNames) => {
            return Promise.all(
                cacheNames.map((cacheName) => {
                    if (cacheName !== CACHE_NAME) {
                        return caches.delete(cacheName);
                    }
                })
            );
        })
    );
    self.clients.claim();
});

self.addEventListener('fetch', (event) => {
    // Solo manejar peticiones GET
    if (event.request.method !== 'GET') return;

    // No interceptar peticiones de navegación (HTML) para evitar problemas con LiveView
    // y asegurar que siempre se obtenga la versión más reciente del servidor
    if (event.request.mode === 'navigate') {
        return;
    }

    event.respondWith(
        caches.match(event.request).then((response) => {
            // Cache-first para assets estáticos
            if (response) {
                return response;
            }
            return fetch(event.request).then((networkResponse) => {
                // Opcional: Cachear assets nuevos dinámicamente si están en /assets/ o /images/
                // Por ahora, simple fetch
                return networkResponse;
            });
        })
    );
});
