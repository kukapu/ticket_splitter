// CopyToClipboard Hook - Copies text to clipboard with visual feedback
export const CopyToClipboard = {
  mounted() {
    const button = this.el
    const targetId = button.dataset.targetId
    const originalText = button.innerHTML

    button.addEventListener('click', async (e) => {
      e.preventDefault()

      const targetInput = document.getElementById(targetId)
      if (!targetInput) {
        console.error('Target input not found:', targetId)
        return
      }

      try {
        // Copy to clipboard
        await navigator.clipboard.writeText(targetInput.value)

        // Visual feedback
        button.innerHTML = '<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path></svg><span class="text-sm font-bold hidden sm:inline">¡Copiado!</span>'
        button.classList.add('bg-success', 'text-success-content')
        button.classList.remove('bg-secondary', 'text-secondary-content')

        // Haptic feedback on mobile
        if (navigator.vibrate) {
          navigator.vibrate(50)
        }

        // Reset after 2 seconds
        setTimeout(() => {
          button.innerHTML = originalText
          button.classList.remove('bg-success', 'text-success-content')
          button.classList.add('bg-secondary', 'text-secondary-content')
        }, 2000)
      } catch (error) {
        console.error('Failed to copy:', error)

        // Fallback for older browsers
        targetInput.select()
        targetInput.setSelectionRange(0, 99999) // For mobile devices
        document.execCommand('copy')

        // Visual feedback for fallback
        button.innerHTML = '<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path></svg><span class="text-sm font-bold hidden sm:inline">¡Copiado!</span>'
        button.classList.add('bg-success', 'text-success-content')
        button.classList.remove('bg-secondary', 'text-secondary-content')

        setTimeout(() => {
          button.innerHTML = originalText
          button.classList.remove('bg-success', 'text-success-content')
          button.classList.add('bg-secondary', 'text-secondary-content')
        }, 2000)
      }
    })
  }
}
