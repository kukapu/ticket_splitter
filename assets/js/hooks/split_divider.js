// SplitDivider Hook - Interactive divider for adjusting percentage splits
export const SplitDivider = {
  mounted() {
    let isDragging = false
    let hasDragged = false
    let startX = 0
    let startPercentage = 0
    let containerWidth = 0
    let divider = this.el
    let container = divider.parentElement
    let animationFrameId = null
    let lastPercentage = null
    let isLocked = false

    // Cache DOM elements for better performance
    const participant1 = container.querySelector('[id^="participant-"][id$="-0"]')
    const participant2 = container.querySelector('[id^="participant-"][id$="-1"]')
    const percent1Display = participant1?.querySelector('.percentage-display')
    const percent2Display = participant2?.querySelector('.percentage-display')

    // Function to get the current user's name from localStorage
    const getCurrentUserName = () => {
      return localStorage.getItem('participant_name') || ''
    }

    // Function to check if current user is in first position
    const isCurrentUserInFirstPosition = () => {
      const currentUserName = getCurrentUserName()
      if (!currentUserName) return true // Default to true if no name

      // Get current participant names
      const participant1Name = participant1?.querySelector('.text-base-content.truncate')?.textContent?.trim() || ''
      const participant2Name = participant2?.querySelector('.text-base-content.truncate')?.textContent?.trim() || ''

      // Check if current user matches the first participant
      return participant1Name === currentUserName
    }

    const updateSplit = (clientX) => {
      const deltaX = clientX - startX
      const percentageChange = (deltaX / containerWidth) * 100
      let newPercentage = startPercentage + percentageChange

      // Clamp between 5% and 95%
      newPercentage = Math.max(5, Math.min(95, newPercentage))

      // Snap to 5% increments
      newPercentage = Math.round(newPercentage / 5) * 5

      // Only update if percentage changed
      if (newPercentage === lastPercentage) {
        return lastPercentage
      }
      lastPercentage = newPercentage

      // Use requestAnimationFrame for smooth visual updates
      if (animationFrameId) {
        cancelAnimationFrame(animationFrameId)
      }

      animationFrameId = requestAnimationFrame(() => {
        // Update visual positions
        divider.style.left = `${newPercentage}%`

        if (participant1 && participant2) {
          participant1.style.width = `${newPercentage}%`
          participant2.style.width = `${100 - newPercentage}%`

          // Update percentage displays
          if (percent1Display) percent1Display.textContent = `${newPercentage}%`
          if (percent2Display) percent2Display.textContent = `${100 - newPercentage}%`
        }
        animationFrameId = null
      })

      return newPercentage
    }

    const handleStart = (e) => {
      // Don't allow dragging if slider is locked by another user
      if (isLocked) {
        e.preventDefault()
        e.stopPropagation()
        return
      }

      e.preventDefault()
      e.stopPropagation()

      isDragging = true
      hasDragged = false // Reset at start of drag
      containerWidth = container.offsetWidth
      startX = e.type.includes('touch') ? e.touches[0].clientX : e.clientX

      const currentLeft = parseFloat(divider.style.left) || 50
      startPercentage = currentLeft

      divider.style.cursor = 'grabbing'
      divider.classList.add('dragging')

      // Lock the slider when starting to drag
      this.pushEvent("lock_slider", {
        group_id: divider.dataset.groupId
      })
    }

    const handleMove = (e) => {
      if (!isDragging) return

      e.preventDefault()
      e.stopPropagation()

      // Mark as dragged if we move more than 3 pixels
      const clientX = e.type.includes('touch') ? e.touches[0].clientX : e.clientX
      if (Math.abs(clientX - startX) > 3) {
        hasDragged = true
      }

      // Update visual position only (no server update during drag)
      updateSplit(clientX)
    }

    const handleEnd = (e) => {
      if (!isDragging) return

      e.preventDefault()
      e.stopPropagation()

      isDragging = false
      divider.style.cursor = 'ew-resize'
      divider.classList.remove('dragging')

      const clientX = e.type.includes('touch') ?
        e.changedTouches[0].clientX :
        divider.getBoundingClientRect().left + (divider.offsetWidth / 2)
      const finalPercentage = updateSplit(clientX)

      // Get the visual percentages (left and right in the UI)
      const leftPercentage = finalPercentage
      const rightPercentage = 100 - finalPercentage

      // Get current user name
      const currentUserName = getCurrentUserName()

      // Get original alphabetical order from data attributes (same as database)
      // participant1 is alphabetically first, participant2 is alphabetically second
      const participant1NameOriginal = divider.dataset.participant1Name || ''
      const participant2NameOriginal = divider.dataset.participant2Name || ''

      // Get participant names from visual position (reordered for UI)
      const participant1NameVisual = participant1?.querySelector('.text-base-content.truncate')?.textContent?.trim() || ''
      const participant2NameVisual = participant2?.querySelector('.text-base-content.truncate')?.textContent?.trim() || ''

      // Map visual percentages to original alphabetical order
      // p1Percentage goes to participant1 (alphabetically first)
      // p2Percentage goes to participant2 (alphabetically second)
      let p1Percentage, p2Percentage

      if (participant1NameVisual === participant1NameOriginal) {
        // Visual order matches original order: left -> p1, right -> p2
        p1Percentage = leftPercentage
        p2Percentage = rightPercentage
      } else {
        // Visual order is reversed: left -> p2, right -> p1
        p1Percentage = rightPercentage
        p2Percentage = leftPercentage
      }

      // Send the final update and unlock the slider
      this.pushEvent("adjust_split_percentage", {
        group_id: divider.dataset.groupId,
        product_id: divider.dataset.productId,
        participant1_percentage: p1Percentage,
        participant2_percentage: p2Percentage
      })

      // Unlock the slider when done dragging
      this.pushEvent("unlock_slider", {
        group_id: divider.dataset.groupId
      })

      // Prevent click event if we dragged
      setTimeout(() => {
        hasDragged = false
      }, 100)
    }

    // Prevent click on container if we just finished dragging
    const handleContainerClick = (e) => {
      if (hasDragged) {
        e.preventDefault()
        e.stopPropagation()
        return false
      }
    }

    // Mouse events
    divider.addEventListener('mousedown', handleStart)
    document.addEventListener('mousemove', handleMove)
    document.addEventListener('mouseup', handleEnd)

    // Touch events
    divider.addEventListener('touchstart', handleStart, { passive: false })
    document.addEventListener('touchmove', handleMove, { passive: false })
    document.addEventListener('touchend', handleEnd)

    // Prevent clicks on the parent container during/after drag
    container.addEventListener('click', handleContainerClick, true)

    // Prevent click propagation from the divider always
    const handleDividerClick = (e) => {
      e.preventDefault()
      e.stopPropagation()
    }
    divider.addEventListener('click', handleDividerClick)

    // Handle server events for slider lock/unlock
    this.handleEvent("slider_locked", ({ group_id, locked_by }) => {
      if (group_id === divider.dataset.groupId) {
        isLocked = true
        divider.style.cursor = 'not-allowed'
        divider.style.opacity = '0.5'
        divider.setAttribute('title', `Bloqueado por ${locked_by}`)
      }
    })

    this.handleEvent("slider_unlocked", ({ group_id }) => {
      if (group_id === divider.dataset.groupId) {
        isLocked = false
        divider.style.cursor = 'ew-resize'
        divider.style.opacity = '1'
        divider.removeAttribute('title')
      }
    })

    // Cleanup on unmount
    this.handleDestroy = () => {
      // Clear any pending animation frame
      if (animationFrameId) {
        cancelAnimationFrame(animationFrameId)
        animationFrameId = null
      }
      document.removeEventListener('mousemove', handleMove)
      document.removeEventListener('mouseup', handleEnd)
      document.removeEventListener('touchmove', handleMove)
      document.removeEventListener('touchend', handleEnd)
      container.removeEventListener('click', handleContainerClick, true)
      divider.removeEventListener('click', handleDividerClick)
    }
  },

  destroyed() {
    if (this.handleDestroy) {
      this.handleDestroy()
    }
  }
}
