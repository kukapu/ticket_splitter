// ImageZoom Hook - Enables pinch-to-zoom and scroll-to-zoom for images
export const ImageZoom = {
  mounted() {
    const container = this.el
    const img = container.querySelector('img')
    if (!img) return

    // State variables
    let scale = 1
    let translateX = 0
    let translateY = 0

    // Pinch state
    let initialDistance = 0
    let initialScale = 1
    let initialMidX = 0
    let initialMidY = 0
    let initialTranslateX = 0
    let initialTranslateY = 0

    // Drag state
    let isDragging = false
    let dragStartX = 0
    let dragStartY = 0
    let dragStartTranslateX = 0
    let dragStartTranslateY = 0

    const minScale = 1
    const maxScale = 4

    const updateTransform = () => {
      img.style.transform = `translate(${translateX}px, ${translateY}px) scale(${scale})`
    }

    // Constrain translation to prevent image from going too far off-screen
    const constrainTranslation = () => {
      if (scale <= 1) {
        translateX = 0
        translateY = 0
        return
      }

      const containerRect = container.getBoundingClientRect()
      const imgRect = img.getBoundingClientRect()

      // Calculate bounds - allow some overshoot but keep at least half the image visible
      const maxTranslateX = Math.max(0, (imgRect.width - containerRect.width) / 2)
      const maxTranslateY = Math.max(0, (imgRect.height - containerRect.height) / 2)

      translateX = Math.max(-maxTranslateX, Math.min(maxTranslateX, translateX))
      translateY = Math.max(-maxTranslateY, Math.min(maxTranslateY, translateY))
    }

    // Get distance between two touch points
    const getDistance = (touch1, touch2) => {
      const dx = touch1.clientX - touch2.clientX
      const dy = touch1.clientY - touch2.clientY
      return Math.sqrt(dx * dx + dy * dy)
    }

    // Get midpoint between two touch points
    const getMidpoint = (touch1, touch2) => {
      return {
        x: (touch1.clientX + touch2.clientX) / 2,
        y: (touch1.clientY + touch2.clientY) / 2
      }
    }

    // Wheel zoom (desktop)
    const handleWheel = (e) => {
      e.preventDefault()
      e.stopPropagation()

      const delta = e.deltaY > 0 ? -0.2 : 0.2
      const newScale = Math.max(minScale, Math.min(maxScale, scale + delta))

      // Get container position
      const rect = container.getBoundingClientRect()
      const cursorX = e.clientX - rect.left
      const cursorY = e.clientY - rect.top
      const centerX = rect.width / 2
      const centerY = rect.height / 2

      // Calculate the focal point relative to current transform
      const focalX = (cursorX - centerX - translateX) / scale
      const focalY = (cursorY - centerY - translateY) / scale

      // Update scale
      const oldScale = scale
      scale = newScale

      // Adjust translation to keep focal point stationary
      translateX = cursorX - centerX - focalX * scale
      translateY = cursorY - centerY - focalY * scale

      // Reset if zoomed out completely
      if (scale <= 1) {
        scale = 1
        translateX = 0
        translateY = 0
      }

      constrainTranslation()
      updateTransform()
    }

    // Touch handlers for pinch-to-zoom
    const handleTouchStart = (e) => {
      if (e.touches.length === 2) {
        // Pinch start - save initial state
        e.preventDefault()

        initialDistance = getDistance(e.touches[0], e.touches[1])
        initialScale = scale
        initialTranslateX = translateX
        initialTranslateY = translateY

        // Get the midpoint in container coordinates
        const mid = getMidpoint(e.touches[0], e.touches[1])
        const rect = container.getBoundingClientRect()
        initialMidX = mid.x - rect.left
        initialMidY = mid.y - rect.top

        isDragging = false
      } else if (e.touches.length === 1 && scale > 1) {
        // Pan start (only when zoomed in)
        isDragging = true
        dragStartX = e.touches[0].clientX
        dragStartY = e.touches[0].clientY
        dragStartTranslateX = translateX
        dragStartTranslateY = translateY
      }
    }

    const handleTouchMove = (e) => {
      if (e.touches.length === 2) {
        // Pinch move
        e.preventDefault()

        const currentDistance = getDistance(e.touches[0], e.touches[1])
        const scaleFactor = currentDistance / initialDistance
        const newScale = Math.max(minScale, Math.min(maxScale, initialScale * scaleFactor))

        // Get the current midpoint
        const mid = getMidpoint(e.touches[0], e.touches[1])
        const rect = container.getBoundingClientRect()
        const currentMidX = mid.x - rect.left
        const currentMidY = mid.y - rect.top
        const centerX = rect.width / 2
        const centerY = rect.height / 2

        // Calculate the focal point in the original image space
        const focalX = (initialMidX - centerX - initialTranslateX) / initialScale
        const focalY = (initialMidY - centerY - initialTranslateY) / initialScale

        // Calculate new translation to keep the focal point at the current mid position
        // and also account for any panning (movement of the midpoint)
        scale = newScale
        translateX = currentMidX - centerX - focalX * scale
        translateY = currentMidY - centerY - focalY * scale

        updateTransform()
      } else if (isDragging && e.touches.length === 1 && scale > 1) {
        // Pan move
        e.preventDefault()

        const deltaX = e.touches[0].clientX - dragStartX
        const deltaY = e.touches[0].clientY - dragStartY

        translateX = dragStartTranslateX + deltaX
        translateY = dragStartTranslateY + deltaY

        updateTransform()
      }
    }

    const handleTouchEnd = (e) => {
      if (e.touches.length < 2) {
        // Pinch ended - constrain and apply final position
        constrainTranslation()

        // Reset to 1 if very close to 1
        if (scale < 1.05) {
          scale = 1
          translateX = 0
          translateY = 0
        }

        updateTransform()

        // If one finger remains and we're zoomed in, prepare for panning
        if (e.touches.length === 1 && scale > 1) {
          isDragging = true
          dragStartX = e.touches[0].clientX
          dragStartY = e.touches[0].clientY
          dragStartTranslateX = translateX
          dragStartTranslateY = translateY
        }
      }

      if (e.touches.length === 0) {
        isDragging = false
        constrainTranslation()
        updateTransform()
      }
    }

    // Double-tap to zoom
    let lastTap = 0
    let lastTapX = 0
    let lastTapY = 0

    const handleDoubleTap = (e) => {
      const now = Date.now()
      const touch = e.changedTouches[0]

      if (now - lastTap < 300) {
        e.preventDefault()

        const rect = container.getBoundingClientRect()
        const tapX = touch.clientX - rect.left
        const tapY = touch.clientY - rect.top
        const centerX = rect.width / 2
        const centerY = rect.height / 2

        if (scale > 1) {
          // Reset zoom
          scale = 1
          translateX = 0
          translateY = 0
        } else {
          // Zoom in to 2x towards tap position
          const focalX = (tapX - centerX) / scale
          const focalY = (tapY - centerY) / scale

          scale = 2
          translateX = tapX - centerX - focalX * scale
          translateY = tapY - centerY - focalY * scale

          constrainTranslation()
        }

        // Smooth animation for double-tap
        img.style.transition = 'transform 0.2s ease-out'
        updateTransform()
        setTimeout(() => {
          img.style.transition = ''
        }, 200)
      }

      lastTap = now
      lastTapX = touch.clientX
      lastTapY = touch.clientY
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
