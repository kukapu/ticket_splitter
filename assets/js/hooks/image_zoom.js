/**
 * ImageZoom Hook - Implementación manual de pinch-to-zoom y pan
 * 
 * Esta implementación NO usa Panzoom porque tiene bugs conocidos con pinch-to-zoom.
 * En su lugar, manejamos los gestos manualmente para garantizar que:
 * 1. El zoom persiste cuando sueltas los dedos
 * 2. Puedes hacer pan después del zoom
 * 3. Puedes hacer zoom incremental (zoom, soltar, zoom más)
 */

export const ImageZoom = {
  // Estado del zoom/pan
  scale: 1,
  translateX: 0,
  translateY: 0,

  // Estado del gesto actual
  initialDistance: 0,
  initialScale: 1,
  initialX: 0,
  initialY: 0,
  initialTranslateX: 0,
  initialTranslateY: 0,

  // Flags
  isPinching: false,
  isPanning: false,

  // Configuración
  minScale: 1,
  maxScale: 8,

  // Referencias DOM
  img: null,
  container: null,

  // Double tap tracking
  lastTap: 0,

  mounted() {
    const img = this.el.querySelector('img')
    if (!img) return

    this.img = img
    this.container = this.el

    // Esperar a que la imagen cargue
    if (img.complete) {
      this.init()
    } else {
      img.addEventListener('load', () => this.init(), { once: true })
    }
  },

  init() {
    const img = this.img
    const container = this.container

    // Configurar estilos iniciales
    img.style.touchAction = 'none'
    img.style.userSelect = 'none'
    img.style.webkitUserSelect = 'none'
    img.style.transformOrigin = 'center center'
    img.style.transition = 'none'

    container.style.touchAction = 'none'
    container.style.userSelect = 'none'
    container.style.overflow = 'hidden'

    // Aplicar transform inicial
    this.applyTransform(false)

    // ========== TOUCH EVENTS ==========

    this.handleTouchStart = (e) => {
      e.preventDefault()
      e.stopPropagation()

      const touches = e.touches

      if (touches.length === 2) {
        // Inicio de pinch zoom
        this.isPinching = true
        this.isPanning = false

        this.initialDistance = this.getDistance(touches[0], touches[1])
        this.initialScale = this.scale

        // Guardar punto medio inicial para pan durante pinch
        const midpoint = this.getMidpoint(touches[0], touches[1])
        this.initialX = midpoint.x
        this.initialY = midpoint.y
        this.initialTranslateX = this.translateX
        this.initialTranslateY = this.translateY

      } else if (touches.length === 1) {
        // Inicio de pan (solo si ya hay zoom)
        if (this.scale > 1) {
          this.isPanning = true
          this.initialX = touches[0].clientX
          this.initialY = touches[0].clientY
          this.initialTranslateX = this.translateX
          this.initialTranslateY = this.translateY
        }

        // Detectar double tap
        const now = Date.now()
        if (now - this.lastTap < 300) {
          this.handleDoubleTap(touches[0])
          this.lastTap = 0
        } else {
          this.lastTap = now
        }
      }
    }

    this.handleTouchMove = (e) => {
      e.preventDefault()
      e.stopPropagation()

      const touches = e.touches

      if (this.isPinching && touches.length === 2) {
        // Calcular nuevo zoom
        const currentDistance = this.getDistance(touches[0], touches[1])
        const distanceRatio = currentDistance / this.initialDistance

        let newScale = this.initialScale * distanceRatio

        // Limitar escala
        newScale = Math.max(this.minScale, Math.min(this.maxScale, newScale))

        // Calcular pan durante pinch (hacia el punto medio)
        const currentMidpoint = this.getMidpoint(touches[0], touches[1])
        const deltaX = currentMidpoint.x - this.initialX
        const deltaY = currentMidpoint.y - this.initialY

        // Ajustar translation considerando el cambio de escala
        this.translateX = this.initialTranslateX + deltaX
        this.translateY = this.initialTranslateY + deltaY
        this.scale = newScale

        this.applyTransform(false)

      } else if (this.isPanning && touches.length === 1) {
        // Pan con un dedo (solo si hay zoom)
        const deltaX = touches[0].clientX - this.initialX
        const deltaY = touches[0].clientY - this.initialY

        this.translateX = this.initialTranslateX + deltaX
        this.translateY = this.initialTranslateY + deltaY

        this.applyTransform(false)
      }
    }

    this.handleTouchEnd = (e) => {
      e.preventDefault()
      e.stopPropagation()

      const remainingTouches = e.touches.length

      if (remainingTouches === 0) {
        // Todos los dedos levantados
        this.isPinching = false
        this.isPanning = false

        // Si el scale es menor que 1, resetear a 1
        if (this.scale < 1) {
          this.scale = 1
          this.translateX = 0
          this.translateY = 0
          this.applyTransform(true)
        }

        // Guardar estado final
        console.log('✅ Zoom state saved:', { scale: this.scale, x: this.translateX, y: this.translateY })

      } else if (remainingTouches === 1 && this.isPinching) {
        // Pasamos de pinch a pan con un dedo
        this.isPinching = false

        if (this.scale > 1) {
          this.isPanning = true
          this.initialX = e.touches[0].clientX
          this.initialY = e.touches[0].clientY
          this.initialTranslateX = this.translateX
          this.initialTranslateY = this.translateY
        }
      }
    }

    // ========== MOUSE WHEEL ZOOM (Desktop) ==========

    this.handleWheel = (e) => {
      e.preventDefault()
      e.stopPropagation()

      const delta = e.deltaY > 0 ? -0.1 : 0.1
      let newScale = this.scale + delta

      // Limitar escala
      newScale = Math.max(this.minScale, Math.min(this.maxScale, newScale))

      // Zoom hacia el punto del cursor
      if (newScale !== this.scale) {
        const rect = this.img.getBoundingClientRect()
        const offsetX = e.clientX - rect.left - rect.width / 2
        const offsetY = e.clientY - rect.top - rect.height / 2

        const scaleRatio = newScale / this.scale
        this.translateX = this.translateX * scaleRatio - offsetX * (scaleRatio - 1)
        this.translateY = this.translateY * scaleRatio - offsetY * (scaleRatio - 1)
        this.scale = newScale

        this.applyTransform(false)
      }
    }

    // ========== CLICK HANDLER ==========

    this.handleClick = (e) => {
      e.stopPropagation()
    }

    this.handleContextMenu = (e) => {
      e.preventDefault()
    }

    // ========== REGISTRAR EVENT LISTENERS ==========

    img.addEventListener('touchstart', this.handleTouchStart, { passive: false })
    img.addEventListener('touchmove', this.handleTouchMove, { passive: false })
    img.addEventListener('touchend', this.handleTouchEnd, { passive: false })
    img.addEventListener('touchcancel', this.handleTouchEnd, { passive: false })

    container.addEventListener('wheel', this.handleWheel, { passive: false })
    container.addEventListener('click', this.handleClick)
    img.addEventListener('contextmenu', this.handleContextMenu)

    console.log('✅ ImageZoom initialized (custom implementation)')
  },

  // ========== MÉTODOS HELPER ==========

  getDistance(touch1, touch2) {
    const dx = touch2.clientX - touch1.clientX
    const dy = touch2.clientY - touch1.clientY
    return Math.sqrt(dx * dx + dy * dy)
  },

  getMidpoint(touch1, touch2) {
    return {
      x: (touch1.clientX + touch2.clientX) / 2,
      y: (touch1.clientY + touch2.clientY) / 2
    }
  },

  applyTransform(animate = false) {
    if (!this.img) return

    if (animate) {
      this.img.style.transition = 'transform 0.3s ease-out'
      setTimeout(() => {
        this.img.style.transition = 'none'
      }, 300)
    }

    this.img.style.transform = `translate(${this.translateX}px, ${this.translateY}px) scale(${this.scale})`
  },

  handleDoubleTap(touch) {
    if (this.scale > 1.1) {
      // Reset zoom
      this.scale = 1
      this.translateX = 0
      this.translateY = 0
    } else {
      // Zoom in to 2.5x centered on tap point
      const rect = this.img.getBoundingClientRect()
      const offsetX = touch.clientX - rect.left - rect.width / 2
      const offsetY = touch.clientY - rect.top - rect.height / 2

      this.scale = 2.5
      this.translateX = -offsetX * 1.5
      this.translateY = -offsetY * 1.5
    }

    this.applyTransform(true)
  },

  destroyed() {
    if (this.img) {
      this.img.removeEventListener('touchstart', this.handleTouchStart)
      this.img.removeEventListener('touchmove', this.handleTouchMove)
      this.img.removeEventListener('touchend', this.handleTouchEnd)
      this.img.removeEventListener('touchcancel', this.handleTouchEnd)
      this.img.removeEventListener('contextmenu', this.handleContextMenu)
    }

    if (this.container) {
      this.container.removeEventListener('wheel', this.handleWheel)
      this.container.removeEventListener('click', this.handleClick)
    }

    console.log('🧹 ImageZoom destroyed')
  }
}
