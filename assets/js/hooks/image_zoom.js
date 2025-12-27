// ImageZoom Hook - Zoom simple con pinch-to-zoom y drag
export const ImageZoom = {
  mounted() {
    const container = this.el
    const img = container.querySelector('img')
    if (!img) return

    // Estado del zoom - PERSISTE entre gestos
    let currentScale = 1
    let currentTranslateX = 0
    let currentTranslateY = 0

    // Estado temporal durante el gesto
    let gestureStartScale = 1
    let gestureStartDistance = 0
    let gestureStartX = 0
    let gestureStartY = 0
    let gestureStartTranslateX = 0
    let gestureStartTranslateY = 0

    // Control de modo
    let isPinching = false
    let isDragging = false

    const minScale = 1
    const maxScale = 4

    // Aplicar transformación - esta es la función que actualiza visualmente la imagen
    const applyTransform = () => {
      img.style.transform = `translate(${currentTranslateX}px, ${currentTranslateY}px) scale(${currentScale})`
      img.style.transformOrigin = 'center center'
      img.style.transition = 'none'
    }

    // Calcular distancia entre dos puntos
    const getDistance = (touch1, touch2) => {
      const dx = touch1.clientX - touch2.clientX
      const dy = touch1.clientY - touch2.clientY
      return Math.sqrt(dx * dx + dy * dy)
    }

    // Prevenir scroll del modal durante cualquier interacción con la imagen
    const preventModalScroll = (e) => {
      const modalScrollContainer = container.closest('[role="dialog"]')
      if (modalScrollContainer && (isPinching || isDragging || e.touches.length > 0)) {
        e.preventDefault()
        e.stopPropagation()
      }
    }

    // INICIO DE GESTO
    const handleTouchStart = (e) => {
      if (e.touches.length === 2) {
        // MODO PINCH: Dos dedos = zoom
        e.preventDefault()
        e.stopPropagation()

        isPinching = true
        isDragging = false

        gestureStartDistance = getDistance(e.touches[0], e.touches[1])
        gestureStartScale = currentScale // Guardar el scale actual al iniciar

      } else if (e.touches.length === 1 && currentScale > 1) {
        // MODO DRAG: Un dedo y hay zoom = mover imagen
        e.preventDefault()
        e.stopPropagation()

        isDragging = true
        isPinching = false

        gestureStartX = e.touches[0].clientX
        gestureStartY = e.touches[0].clientY
        gestureStartTranslateX = currentTranslateX
        gestureStartTranslateY = currentTranslateY
      }
    }

    // DURANTE EL GESTO
    const handleTouchMove = (e) => {
      if (isPinching && e.touches.length === 2) {
        // PINCH ZOOM
        e.preventDefault()
        e.stopPropagation()

        const currentDistance = getDistance(e.touches[0], e.touches[1])
        const ratio = currentDistance / gestureStartDistance

        // Calcular nuevo scale basado en el scale al inicio del gesto
        let newScale = gestureStartScale * ratio
        newScale = Math.max(minScale, Math.min(maxScale, newScale))

        // ACTUALIZAR el scale actual
        currentScale = newScale

        // Si volvemos a scale 1, resetear posición
        if (currentScale === minScale) {
          currentTranslateX = 0
          currentTranslateY = 0
        }

        applyTransform()

      } else if (isDragging && e.touches.length === 1 && currentScale > 1) {
        // DRAG/PAN
        e.preventDefault()
        e.stopPropagation()

        const deltaX = e.touches[0].clientX - gestureStartX
        const deltaY = e.touches[0].clientY - gestureStartY

        // ACTUALIZAR la posición actual
        currentTranslateX = gestureStartTranslateX + deltaX
        currentTranslateY = gestureStartTranslateY + deltaY

        applyTransform()
      }
    }

    // FIN DEL GESTO
    const handleTouchEnd = (e) => {
      // Cuando soltamos dedos, NO reseteamos currentScale, currentTranslateX, currentTranslateY
      // Solo actualizamos los flags de modo

      if (e.touches.length < 2) {
        isPinching = false
      }

      if (e.touches.length === 0) {
        isDragging = false

        // Solo resetear posición si no hay zoom
        if (currentScale === minScale) {
          currentTranslateX = 0
          currentTranslateY = 0
          applyTransform()
        }
      }
    }

    // DOBLE TAP para zoom rápido
    let lastTapTime = 0
    const handleDoubleTap = (e) => {
      const now = Date.now()
      const timeSinceLastTap = now - lastTapTime

      if (timeSinceLastTap < 300 && timeSinceLastTap > 0) {
        e.preventDefault()
        e.stopPropagation()

        if (currentScale > 1) {
          // Resetear zoom
          currentScale = 1
          currentTranslateX = 0
          currentTranslateY = 0
        } else {
          // Zoom 2x
          currentScale = 2
          currentTranslateX = 0
          currentTranslateY = 0
        }

        applyTransform()
      }

      lastTapTime = now
    }

    // Prevenir que el click cierre el modal
    const preventClickPropagation = (e) => {
      if (currentScale > 1 || isPinching || isDragging) {
        e.stopPropagation()
      }
    }

    // Registrar listeners
    // IMPORTANTE: passive: false permite que preventDefault funcione
    container.addEventListener('touchstart', handleTouchStart, { passive: false })
    container.addEventListener('touchmove', handleTouchMove, { passive: false })
    container.addEventListener('touchend', handleTouchEnd, { passive: false })
    container.addEventListener('touchmove', preventModalScroll, { passive: false })
    container.addEventListener('click', preventClickPropagation, { passive: false })
    img.addEventListener('touchend', handleDoubleTap, { passive: false })

    // Prevenir scroll del contenedor del modal
    const modalScrollContainer = container.closest('[role="dialog"]')
    if (modalScrollContainer) {
      const preventScroll = (e) => {
        if (isPinching || isDragging || currentScale > 1) {
          e.preventDefault()
        }
      }
      modalScrollContainer.addEventListener('touchmove', preventScroll, { passive: false })

      // Guardar referencia para cleanup
      this.modalScrollContainer = modalScrollContainer
      this.preventScroll = preventScroll
    }

    // Cleanup
    this.cleanup = () => {
      container.removeEventListener('touchstart', handleTouchStart)
      container.removeEventListener('touchmove', handleTouchMove)
      container.removeEventListener('touchend', handleTouchEnd)
      container.removeEventListener('touchmove', preventModalScroll)
      container.removeEventListener('click', preventClickPropagation)
      img.removeEventListener('touchend', handleDoubleTap)

      if (this.modalScrollContainer && this.preventScroll) {
        this.modalScrollContainer.removeEventListener('touchmove', this.preventScroll)
      }
    }
  },

  destroyed() {
    if (this.cleanup) {
      this.cleanup()
    }
  }
}
