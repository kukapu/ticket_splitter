// SwipeAndLongPressHandler Hook - Combined functionality for swipe and long press
export const SwipeAndLongPressHandler = {
  mounted() {
    let startX = 0
    let startY = 0
    let el = this.el

    // Swipe functionality
    const handleTouchStart = (e) => {
      startX = e.touches[0].clientX
      startY = e.touches[0].clientY
    }

    const handleTouchEnd = (e) => {
      const endX = e.changedTouches[0].clientX
      const endY = e.changedTouches[0].clientY
      const diffX = endX - startX
      const diffY = endY - startY

      // Swipe right detected (horizontal swipe > 100px, vertical < 50px)
      if (diffX > 100 && Math.abs(diffY) < 50) {
        const productId = el.dataset.productId
        this.pushEvent("toggle_common", { product_id: productId })

        // Visual feedback
        el.style.transform = 'translateX(20px)'
        setTimeout(() => {
          el.style.transform = 'translateX(0)'
        }, 200)
      }
    }

    // Long press functionality
    let pressTimer = null
    let isLongPress = false

    const startPress = (e) => {
      isLongPress = false
      el.style.cursor = 'grabbing'

      pressTimer = setTimeout(() => {
        isLongPress = true
        el.style.cursor = 'pointer'

        const productId = el.dataset.productId
        const isCommon = el.dataset.isCommon === 'true'

        // Different visual feedback for make/remove common
        if (isCommon) {
          // Removing from common - red glow
          el.style.transform = 'scale(0.98)'
          el.style.boxShadow = '0 0 20px rgba(239, 68, 68, 0.5)'

          if (navigator.vibrate) {
            navigator.vibrate([50, 50, 50]) // Triple vibration for removal
          }

          this.pushEvent("remove_from_common", { product_id: productId })
        } else {
          // Making common - purple glow
          el.style.transform = 'scale(1.02)'
          el.style.boxShadow = '0 0 20px rgba(147, 51, 234, 0.5)'

          if (navigator.vibrate) {
            navigator.vibrate(50) // Single vibration for addition
          }

          this.pushEvent("make_common", { product_id: productId })
        }

        // Reset visual feedback after a delay
        setTimeout(() => {
          el.style.transform = 'scale(1)'
          el.style.boxShadow = ''
        }, 300)
      }, 800) // 800ms for long press
    }

    const cancelPress = () => {
      if (pressTimer) {
        clearTimeout(pressTimer)
        pressTimer = null
      }
      el.style.cursor = ''
      el.style.transform = ''
      el.style.boxShadow = ''
    }

    const handleClick = (e) => {
      if (isLongPress) {
        e.preventDefault()
        e.stopPropagation()
        isLongPress = false
      }
    }

    // Touch events for both swipe and long press
    el.addEventListener('touchstart', (e) => {
      handleTouchStart(e)
      startPress(e)
    }, { passive: false })

    el.addEventListener('touchend', (e) => {
      handleTouchEnd(e)
      cancelPress()
    })

    el.addEventListener('touchcancel', cancelPress)
    el.addEventListener('touchmove', cancelPress)

    // Mouse events for long press
    el.addEventListener('mousedown', startPress)
    el.addEventListener('mouseup', cancelPress)
    el.addEventListener('mouseleave', cancelPress)
    el.addEventListener('click', handleClick)

    // Cleanup on unmount
    this.handleDestroy = () => {
      if (pressTimer) {
        clearTimeout(pressTimer)
      }
      el.removeEventListener('touchstart', handleTouchStart)
      el.removeEventListener('touchend', handleTouchEnd)
      el.removeEventListener('touchcancel', cancelPress)
      el.removeEventListener('touchmove', cancelPress)
      el.removeEventListener('mousedown', startPress)
      el.removeEventListener('mouseup', cancelPress)
      el.removeEventListener('mouseleave', cancelPress)
      el.removeEventListener('click', handleClick)
    }
  },

  destroyed() {
    if (this.handleDestroy) {
      this.handleDestroy()
    }
  }
}
