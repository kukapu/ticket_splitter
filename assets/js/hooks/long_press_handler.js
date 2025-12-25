// LongPressHandler Hook - Detects long press to toggle products common status
export const LongPressHandler = {
  mounted() {
    let pressTimer = null
    let isLongPress = false
    let el = this.el

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

    // Mouse events
    el.addEventListener('mousedown', startPress)
    el.addEventListener('mouseup', cancelPress)
    el.addEventListener('mouseleave', cancelPress)
    el.addEventListener('click', handleClick)

    // Touch events
    el.addEventListener('touchstart', startPress, { passive: false })
    el.addEventListener('touchend', cancelPress)
    el.addEventListener('touchcancel', cancelPress)
    el.addEventListener('touchmove', cancelPress)

    // Cleanup on unmount
    this.handleDestroy = () => {
      if (pressTimer) {
        clearTimeout(pressTimer)
      }
      el.removeEventListener('mousedown', startPress)
      el.removeEventListener('mouseup', cancelPress)
      el.removeEventListener('mouseleave', cancelPress)
      el.removeEventListener('click', handleClick)
      el.removeEventListener('touchstart', startPress)
      el.removeEventListener('touchend', cancelPress)
      el.removeEventListener('touchcancel', cancelPress)
      el.removeEventListener('touchmove', cancelPress)
    }
  },

  destroyed() {
    if (this.handleDestroy) {
      this.handleDestroy()
    }
  }
}
