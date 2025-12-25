// Keyboard detection using VisualViewport API
// Uses inline transform to smoothly reposition the modal when keyboard opens
export function initKeyboardDetection() {
  if (!window.visualViewport) {
    return
  }

  let isKeyboardVisible = false

  const handleViewportChange = () => {
    const viewport = window.visualViewport
    const modal = document.getElementById('user-settings-modal')
    const modalContent = modal?.querySelector(':scope > div')

    if (!modal || !modalContent) return

    // Check if modal is visible - if not, reset state and exit early
    if (!modal.classList.contains('flex')) {
      if (isKeyboardVisible) {
        isKeyboardVisible = false
        document.body.classList.remove('keyboard-is-open')
        modalContent.style.transform = ''
      }
      return
    }

    // Calculate the offset needed to keep modal visible
    const keyboardHeight = window.innerHeight - viewport.height
    const isKeyboardOpen = keyboardHeight > window.innerHeight * 0.15 // More than 15% of screen is keyboard

    if (isKeyboardOpen && !isKeyboardVisible) {
      isKeyboardVisible = true
      document.body.classList.add('keyboard-is-open')
      // Apply transform to move modal up smoothly
      // We want to move it up by about 15% of viewport height when keyboard is open, plus 50px extra
      const translateY = Math.min(viewport.height * 0.15, keyboardHeight * 0.3) + 50
      modalContent.style.transform = `translateY(-${translateY}px)`
    } else if (!isKeyboardOpen && isKeyboardVisible) {
      isKeyboardVisible = false
      document.body.classList.remove('keyboard-is-open')
      modalContent.style.transform = ''
    }
  }

  // Use both resize and scroll events for better coverage
  window.visualViewport.addEventListener('resize', handleViewportChange)
  window.visualViewport.addEventListener('scroll', handleViewportChange)

  // Also check on orientation change
  window.addEventListener('orientationchange', () => setTimeout(handleViewportChange, 300))
}
