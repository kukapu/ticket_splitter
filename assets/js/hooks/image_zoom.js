// ImageZoom Hook - Enables pinch-to-zoom and scroll-to-zoom for images
export const ImageZoom = {
  mounted() {
    const container = this.el
    const img = container.querySelector('img')
    if (!img) return

    // Estado del zoom y posición
    let scale = 1
    let translateX = 0
    let translateY = 0

    // Variables para pinch-to-zoom
    let initialDistance = 0
    let initialScale = 1
    let initialMidpoint = { x: 0, y: 0 }
    let isPinching = false

    // Variables para pan/drag
    let isDragging = false
    let dragStartX = 0
    let dragStartY = 0
    let initialTranslateX = 0
    let initialTranslateY = 0

    const minScale = 1
    const maxScale = 4

    // Aplicar transformación a la imagen
    const updateTransform = () => {
      img.style.transform = `translate(${translateX}px, ${translateY}px) scale(${scale})`
      img.style.transformOrigin = 'center center'
      img.style.transition = 'none'
    }

    // Calcular distancia entre dos puntos touch
    const getDistance = (touch1, touch2) => {
      const dx = touch1.clientX - touch2.clientX
      const dy = touch1.clientY - touch2.clientY
      return Math.sqrt(dx * dx + dy * dy)
    }

    // Calcular punto medio entre dos touches
    const getMidpoint = (touch1, touch2) => {
      return {
        x: (touch1.clientX + touch2.clientX) / 2,
        y: (touch1.clientY + touch2.clientY) / 2
      }
    }

    // Manejar inicio de touch
    const handleTouchStart = (e) => {
      if (e.touches.length === 2) {
        // Inicio de pinch con dos dedos
        e.preventDefault()
        isPinching = true
        isDragging = false

        initialDistance = getDistance(e.touches[0], e.touches[1])
        initialScale = scale
        initialMidpoint = getMidpoint(e.touches[0], e.touches[1])

      } else if (e.touches.length === 1 && scale > 1) {
        // Inicio de drag (solo si hay zoom)
        isDragging = true
        isPinching = false

        dragStartX = e.touches[0].clientX
        dragStartY = e.touches[0].clientY
        initialTranslateX = translateX
        initialTranslateY = translateY
      }
    }

    // Manejar movimiento de touch
    const handleTouchMove = (e) => {
      if (isPinching && e.touches.length === 2) {
        e.preventDefault()
        e.stopPropagation()

        const currentDistance = getDistance(e.touches[0], e.touches[1])
        const currentMidpoint = getMidpoint(e.touches[0], e.touches[1])

        // Calcular nuevo scale basado en el cambio de distancia
        const scaleChange = currentDistance / initialDistance
        let newScale = initialScale * scaleChange
        newScale = Math.max(minScale, Math.min(maxScale, newScale))

        // Actualizar scale
        scale = newScale

        // Si hacemos zoom out completo, resetear posición
        if (scale === minScale) {
          translateX = 0
          translateY = 0
        } else {
          // Ajustar translación para mantener el punto medio fijo
          const midpointDeltaX = currentMidpoint.x - initialMidpoint.x
          const midpointDeltaY = currentMidpoint.y - initialMidpoint.y
          translateX += midpointDeltaX * 0.5
          translateY += midpointDeltaY * 0.5
        }

        updateTransform()

      } else if (isDragging && e.touches.length === 1 && scale > 1) {
        e.preventDefault()
        e.stopPropagation()

        const deltaX = e.touches[0].clientX - dragStartX
        const deltaY = e.touches[0].clientY - dragStartY

        translateX = initialTranslateX + deltaX
        translateY = initialTranslateY + deltaY

        updateTransform()
      }
    }

    // Manejar fin de touch
    const handleTouchEnd = (e) => {
      // Si quedan menos de 2 dedos, terminar pinch
      if (e.touches.length < 2) {
        isPinching = false
      }

      // Si no quedan dedos en la pantalla
      if (e.touches.length === 0) {
        isDragging = false

        // Solo resetear posición si el zoom está en el mínimo
        if (scale === minScale) {
          translateX = 0
          translateY = 0
          updateTransform()
        }
      }

      // Si queda 1 dedo después del pinch y hay zoom, permitir drag
      if (e.touches.length === 1 && isPinching && scale > 1) {
        isPinching = false
        isDragging = true
        dragStartX = e.touches[0].clientX
        dragStartY = e.touches[0].clientY
        initialTranslateX = translateX
        initialTranslateY = translateY
      }
    }

    // Prevenir scroll del modal durante gestos
    const handleTouchCancel = (e) => {
      isPinching = false
      isDragging = false
    }

    // Wheel zoom (desktop)
    const handleWheel = (e) => {
      e.preventDefault()
      e.stopPropagation()

      const delta = e.deltaY > 0 ? -0.2 : 0.2
      const newScale = Math.max(minScale, Math.min(maxScale, scale + delta))

      // Zoom hacia la posición del cursor
      const rect = container.getBoundingClientRect()
      const x = e.clientX - rect.left
      const y = e.clientY - rect.top
      const centerX = rect.width / 2
      const centerY = rect.height / 2

      if (newScale > scale) {
        translateX += (centerX - x) * 0.1
        translateY += (centerY - y) * 0.1
      } else if (newScale === minScale) {
        translateX = 0
        translateY = 0
      }

      scale = newScale
      updateTransform()
    }

    // Doble tap para zoom
    let lastTap = 0
    const handleDoubleTap = (e) => {
      const now = Date.now()
      if (now - lastTap < 300) {
        e.preventDefault()
        if (scale > 1) {
          scale = 1
          translateX = 0
          translateY = 0
        } else {
          scale = 2
        }
        updateTransform()
      }
      lastTap = now
    }

    // Prevenir click en la imagen para no cerrar el modal
    const handleClick = (e) => {
      e.stopPropagation()
    }

    // Registrar event listeners
    container.addEventListener('wheel', handleWheel, { passive: false })
    container.addEventListener('touchstart', handleTouchStart, { passive: false })
    container.addEventListener('touchmove', handleTouchMove, { passive: false })
    container.addEventListener('touchend', handleTouchEnd, { passive: false })
    container.addEventListener('touchcancel', handleTouchCancel, { passive: false })
    container.addEventListener('click', handleClick)
    img.addEventListener('touchend', handleDoubleTap)

    // Cleanup
    this.handleDestroy = () => {
      container.removeEventListener('wheel', handleWheel)
      container.removeEventListener('touchstart', handleTouchStart)
      container.removeEventListener('touchmove', handleTouchMove)
      container.removeEventListener('touchend', handleTouchEnd)
      container.removeEventListener('touchcancel', handleTouchCancel)
      container.removeEventListener('click', handleClick)
      img.removeEventListener('touchend', handleDoubleTap)
    }
  },

  destroyed() {
    if (this.handleDestroy) {
      this.handleDestroy()
    }
  }
}
