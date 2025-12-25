// SwipeHandler Hook - Detects swipe right gestures
export const SwipeHandler = {
  mounted() {
    let startX = 0
    let startY = 0
    let el = this.el

    el.addEventListener('touchstart', (e) => {
      startX = e.touches[0].clientX
      startY = e.touches[0].clientY
    }, { passive: true })

    el.addEventListener('touchend', (e) => {
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
    }, { passive: true })
  }
}
