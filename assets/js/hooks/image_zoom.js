// ImageZoom Hook - Enables pinch-to-zoom and scroll-to-zoom for images
export const ImageZoom = {
  mounted() {
    const container = this.el
    const img = container.querySelector('img')
    if (!img) return

    let scale = 1
    let translateX = 0
    let translateY = 0
    let lastScale = 1
    let lastTranslateX = 0
    let lastTranslateY = 0
    let initialDistance = 0
    let isPinching = false
    let isDragging = false
    let startX = 0
    let startY = 0

    const minScale = 1
    const maxScale = 4

    const updateTransform = () => {
      img.style.transform = `translate(${translateX}px, ${translateY}px) scale(${scale})`
    }

    // Wheel zoom (desktop)
    const handleWheel = (e) => {
      e.preventDefault()
      e.stopPropagation()

      const delta = e.deltaY > 0 ? -0.2 : 0.2
      const newScale = Math.max(minScale, Math.min(maxScale, scale + delta))

      // Zoom towards cursor position
      const rect = container.getBoundingClientRect()
      const x = e.clientX - rect.left
      const y = e.clientY - rect.top
      const centerX = rect.width / 2
      const centerY = rect.height / 2

      if (newScale > scale) {
        // Zooming in: move towards cursor
        translateX += (centerX - x) * 0.1
        translateY += (centerY - y) * 0.1
      } else if (newScale === minScale) {
        // Reset position when fully zoomed out
        translateX = 0
        translateY = 0
      }

      scale = newScale
      updateTransform()
    }

    // Touch handlers for pinch-to-zoom
    const getDistance = (touch1, touch2) => {
      const dx = touch1.clientX - touch2.clientX
      const dy = touch1.clientY - touch2.clientY
      return Math.sqrt(dx * dx + dy * dy)
    }

    const handleTouchStart = (e) => {
      if (e.touches.length === 2) {
        // Pinch start
        isPinching = true
        isDragging = false
        initialDistance = getDistance(e.touches[0], e.touches[1])
        lastScale = scale
      } else if (e.touches.length === 1 && scale > 1) {
        // Pan start (only when zoomed in)
        isDragging = true
        startX = e.touches[0].clientX - translateX
        startY = e.touches[0].clientY - translateY
        lastTranslateX = translateX
        lastTranslateY = translateY
      }
    }

    const handleTouchMove = (e) => {
      if (isPinching && e.touches.length === 2) {
        e.preventDefault()
        const currentDistance = getDistance(e.touches[0], e.touches[1])
        const delta = currentDistance / initialDistance
        scale = Math.max(minScale, Math.min(maxScale, lastScale * delta))
        updateTransform()
      } else if (isDragging && e.touches.length === 1 && scale > 1) {
        e.preventDefault()
        translateX = e.touches[0].clientX - startX
        translateY = e.touches[0].clientY - startY
        updateTransform()
      }
    }

    const handleTouchEnd = (e) => {
      if (e.touches.length < 2) {
        isPinching = false
        lastScale = scale
      }
      if (e.touches.length === 0) {
        isDragging = false

        // Reset if scale is 1
        if (scale === 1) {
          translateX = 0
          translateY = 0
          updateTransform()
        }
      }
    }

    // Double-tap to zoom
    let lastTap = 0
    const handleDoubleTap = (e) => {
      const now = Date.now()
      if (now - lastTap < 300) {
        e.preventDefault()
        if (scale > 1) {
          // Reset zoom
          scale = 1
          translateX = 0
          translateY = 0
        } else {
          // Zoom in to 2x
          scale = 2
        }
        updateTransform()
      }
      lastTap = now
    }

    // Prevent click propagation to close modal when interacting with image
    const handleClick = (e) => {
      e.stopPropagation()
    }

    // Add event listeners
    container.addEventListener('wheel', handleWheel, { passive: false })
    container.addEventListener('touchstart', handleTouchStart, { passive: false })
    container.addEventListener('touchmove', handleTouchMove, { passive: false })
    container.addEventListener('touchend', handleTouchEnd)
    container.addEventListener('click', handleClick)
    img.addEventListener('touchend', handleDoubleTap)

    // Cleanup
    this.handleDestroy = () => {
      container.removeEventListener('wheel', handleWheel)
      container.removeEventListener('touchstart', handleTouchStart)
      container.removeEventListener('touchmove', handleTouchMove)
      container.removeEventListener('touchend', handleTouchEnd)
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
