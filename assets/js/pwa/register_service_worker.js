// Service Worker registration and management for PWA functionality
export function registerServiceWorker() {
  navigator.serviceWorker
    .register('/service-worker.js', { scope: '/' })
    .then((registration) => {
      console.log('✓ Service Worker registrado exitosamente:', registration.scope)

      // Escuchar actualizaciones
      registration.addEventListener('updatefound', () => {
        const newWorker = registration.installing
        if (newWorker) {
          newWorker.addEventListener('statechange', () => {
            if (newWorker.state === 'installed' && navigator.serviceWorker.controller) {
              // Notificar al usuario que hay actualización disponible
              console.log('Nueva versión disponible. Recarga la página para actualizar.')
              // Opcional: mostrar notificación al usuario
              notifyUserAboutUpdate()
            }
          })
        }
      })

      // Solicitar actualización periódicamente (cada hora)
      setInterval(() => {
        registration.update()
      }, 60 * 60 * 1000)
    })
    .catch((error) => {
      console.error('✗ Error al registrar Service Worker:', error)
    })
}

function notifyUserAboutUpdate() {
  // Crear elemento de notificación visual
  const notification = document.createElement('div')
  notification.id = 'pwa-update-notification'
  notification.innerHTML = `
    <div style="
      position: fixed;
      bottom: 20px;
      left: 50%;
      transform: translateX(-50%);
      background: linear-gradient(135deg, #7B61FF 0%, #6B51EF 100%);
      color: white;
      padding: 1rem 1.5rem;
      border-radius: 12px;
      box-shadow: 0 10px 40px rgba(123, 97, 255, 0.4);
      z-index: 10000;
      display: flex;
      align-items: center;
      gap: 1rem;
      font-family: system-ui, -apple-system, sans-serif;
      animation: slideUp 0.3s ease-out;
      max-width: calc(100vw - 40px);
    ">
      <span style="font-size: 0.95rem;">Nueva versión disponible</span>
      <button onclick="window.location.reload()" style="
        background: white;
        color: #7B61FF;
        border: none;
        padding: 0.5rem 1rem;
        border-radius: 8px;
        font-weight: 600;
        cursor: pointer;
        font-size: 0.85rem;
        white-space: nowrap;
      ">Actualizar</button>
      <button onclick="this.parentElement.parentElement.remove()" style="
        background: transparent;
        color: white;
        border: none;
        padding: 0.25rem;
        cursor: pointer;
        opacity: 0.8;
      ">✕</button>
    </div>
    <style>
      @keyframes slideUp {
        from { opacity: 0; transform: translateX(-50%) translateY(20px); }
        to { opacity: 1; transform: translateX(-50%) translateY(0); }
      }
    </style>
  `

  // Remover notificación existente si hay una
  const existing = document.getElementById('pwa-update-notification')
  if (existing) existing.remove()

  document.body.appendChild(notification)
}

// Manejar cuando un nuevo Service Worker toma control
let refreshing = false
navigator.serviceWorker?.addEventListener('controllerchange', () => {
  if (!refreshing) {
    refreshing = true
    window.location.reload()
  }
})
