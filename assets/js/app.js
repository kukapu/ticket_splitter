// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import { hooks as colocatedHooks } from "phoenix-colocated/ticket_splitter"
import topbar from "../vendor/topbar"
import QRCode from "qrcode"
// Cropper.js for image cropping
import Cropper from "cropperjs"
import "cropperjs/dist/cropper.css"

// Custom Hooks
const Hooks = {}

// Keyboard detection using VisualViewport API
// Uses inline transform to smoothly reposition the modal when keyboard opens
if (window.visualViewport) {
  let isKeyboardVisible = false;

  const handleViewportChange = () => {
    const viewport = window.visualViewport;
    const modal = document.getElementById('user-settings-modal');
    const modalContent = modal?.querySelector(':scope > div');

    if (!modal || !modalContent) return;

    // Check if modal is visible - if not, reset state and exit early
    if (!modal.classList.contains('flex')) {
      if (isKeyboardVisible) {
        isKeyboardVisible = false;
        document.body.classList.remove('keyboard-is-open');
        modalContent.style.transform = '';
      }
      return;
    }

    // Calculate the offset needed to keep modal visible
    const keyboardHeight = window.innerHeight - viewport.height;
    const isKeyboardOpen = keyboardHeight > window.innerHeight * 0.15; // More than 15% of screen is keyboard

    if (isKeyboardOpen && !isKeyboardVisible) {
      isKeyboardVisible = true;
      document.body.classList.add('keyboard-is-open');
      // Apply transform to move modal up smoothly
      // We want to move it up by about 15% of viewport height when keyboard is open, plus 50px extra
      const translateY = Math.min(viewport.height * 0.15, keyboardHeight * 0.3) + 50;
      modalContent.style.transform = `translateY(-${translateY}px)`;
    } else if (!isKeyboardOpen && isKeyboardVisible) {
      isKeyboardVisible = false;
      document.body.classList.remove('keyboard-is-open');
      modalContent.style.transform = '';
    }
  };

  // Use both resize and scroll events for better coverage
  window.visualViewport.addEventListener('resize', handleViewportChange);
  window.visualViewport.addEventListener('scroll', handleViewportChange);

  // Also check on orientation change
  window.addEventListener('orientationchange', () => setTimeout(handleViewportChange, 300));
}

// ParticipantStorage Hook - Manages participant name in localStorage
Hooks.ParticipantStorage = {
  mounted() {
    const name = localStorage.getItem('participant_name')
    // Normalize name to lowercase for case-insensitive comparison
    const normalizedName = name ? name.toLowerCase() : ""
    this.pushEvent("participant_name_from_storage", { name: normalizedName })

    this.handleEvent("save_participant_name", ({ name }) => {
      // Normalize name to lowercase before saving
      const normalizedName = name ? name.toLowerCase() : ""
      localStorage.setItem('participant_name', normalizedName)
    })

    // Handle opening the user settings modal from the header
    this.handleEvent("open_user_settings_modal", (payload) => {
      if (window.openUserSettingsModal) {
        // Pass editMode=true to open directly in edit mode (for new users)
        window.openUserSettingsModal(payload?.editMode ?? true)
      }
    })

    // Handle ticket history saving
    this.handleEvent("save_ticket_to_history", ({ ticket }) => {
      this.saveTicketToHistory(ticket)
    })

    // Listen for user name change requests from the modal
    this.handleUserNameChange = (event) => {
      const { old_name, new_name } = event.detail
      console.log('🔄 User name change requested:', { old_name, new_name })
      
      // Push event to LiveView for validation
      this.pushEvent("change_participant_name", {
        old_name: old_name,
        new_name: new_name
      })
    }
    
    document.addEventListener('user-name-change-request', this.handleUserNameChange)

    // Handle successful name change from server
    this.handleEvent("name_change_success", () => {
      console.log('✅ Name changed successfully')
      // Name was already saved to localStorage by the server
      // Flash message will be shown automatically by Phoenix
    })

    // Handle name change errors from server
    this.handleEvent("name_change_error", () => {
      console.error('❌ Name change error')
      
      // Reopen modal in edit mode to allow user to try again
      // Flash error message will be shown automatically by Phoenix
      if (window.openUserSettingsModal) {
        setTimeout(() => {
          window.openUserSettingsModal(true)
        }, 100)
      }
    })
  },

  destroyed() {
    // Clean up event listener
    if (this.handleUserNameChange) {
      document.removeEventListener('user-name-change-request', this.handleUserNameChange)
    }
  },

  saveTicketToHistory(ticket) {
    try {
      // Get existing history from localStorage
      const history = JSON.parse(localStorage.getItem('ticket_history') || '[]')

      // Check if ticket already exists
      const existingIndex = history.findIndex(t => t.id === ticket.id)

      // Create new entry with timestamp
      const newEntry = {
        id: ticket.id,
        merchant_name: ticket.merchant_name,
        date: ticket.date,
        url: `/tickets/${ticket.id}`,
        visited_at: Date.now()
      }

      // Remove existing entry if duplicate
      if (existingIndex >= 0) {
        history.splice(existingIndex, 1)
      }

      // Add to beginning (most recent first)
      history.unshift(newEntry)

      // Keep only last 100 entries
      if (history.length > 100) {
        history.pop()
      }

      // Save back to localStorage
      localStorage.setItem('ticket_history', JSON.stringify(history))
    } catch (error) {
      // Silently fail if localStorage is disabled or quota exceeded
      console.warn('Could not save ticket to history:', error)
    }
  }
}

// TicketHistory Hook - Manages ticket history display on home page
Hooks.TicketHistory = {
  mounted() {
    this.loadHistory()

    this.handleEvent("delete_ticket_from_history", ({ id }) => {
      this.deleteTicketFromHistory(id)
    })

    // Handle saving ticket to history (when ticket is created from home page)
    this.handleEvent("save_ticket_to_history", ({ ticket }) => {
      this.saveTicketToHistory(ticket)
      // Reload history to update the UI immediately
      this.loadHistory()
    })
  },

  saveTicketToHistory(ticket) {
    try {
      // Get existing history from localStorage
      const history = JSON.parse(localStorage.getItem('ticket_history') || '[]')

      // Check if ticket already exists
      const existingIndex = history.findIndex(t => t.id === ticket.id)

      // Create new entry with timestamp
      const newEntry = {
        id: ticket.id,
        merchant_name: ticket.merchant_name,
        date: ticket.date,
        url: `/tickets/${ticket.id}`,
        visited_at: Date.now()
      }

      // Remove existing entry if duplicate
      if (existingIndex >= 0) {
        history.splice(existingIndex, 1)
      }

      // Add to beginning (most recent first)
      history.unshift(newEntry)

      // Keep only last 100 entries
      if (history.length > 100) {
        history.pop()
      }

      // Save back to localStorage
      localStorage.setItem('ticket_history', JSON.stringify(history))
    } catch (error) {
      console.warn('Could not save ticket to history:', error)
    }
  },

  loadHistory() {
    try {
      // Load history from localStorage
      const history = JSON.parse(localStorage.getItem('ticket_history') || '[]')

      // Push to LiveView for rendering
      this.pushEvent("history_loaded", { tickets: history })
    } catch (error) {
      // If localStorage fails or JSON is corrupted, send empty array
      console.warn('Could not load ticket history:', error)
      this.pushEvent("history_loaded", { tickets: [] })
    }
  },

  deleteTicketFromHistory(ticketId) {
    try {
      // Get existing history
      const history = JSON.parse(localStorage.getItem('ticket_history') || '[]')

      // Filter out the ticket
      const newHistory = history.filter(t => t.id !== ticketId)

      // Save back to localStorage
      localStorage.setItem('ticket_history', JSON.stringify(newHistory))
    } catch (error) {
      console.warn('Could not delete ticket from history:', error)
    }
  }
}

// UserSettings Hook - Manages user settings in localStorage (for header user modal)
Hooks.UserSettings = {
  mounted() {
    // Load the current user name and send to LiveView
    this.loadUserName()

    // Handle save event from LiveView
    this.handleEvent("save_user_name", ({ name }) => {
      const normalizedName = name ? name.toLowerCase().trim() : ""
      localStorage.setItem('participant_name', normalizedName)
      // Confirm save back to LiveView
      this.pushEvent("user_name_saved", { name: normalizedName })
    })

    // Handle request to load username
    this.handleEvent("request_user_name", () => {
      this.loadUserName()
    })
  },

  loadUserName() {
    const name = localStorage.getItem('participant_name') || ""
    this.pushEvent("user_name_loaded", { name: name })
  }
}

// SwipeHandler Hook - Detects swipe right gestures
Hooks.SwipeHandler = {
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

// LongPressHandler Hook - Detects long press to toggle products common status
Hooks.LongPressHandler = {
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

// SwipeAndLongPressHandler Hook - Combined functionality for swipe and long press
Hooks.SwipeAndLongPressHandler = {
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

// SplitDivider Hook - Interactive divider for adjusting percentage splits
Hooks.SplitDivider = {
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
      const participant1Name = participant1?.querySelector('.text-base-content.truncate')?.textContent?.trim()?.toLowerCase() || ''
      const participant2Name = participant2?.querySelector('.text-base-content.truncate')?.textContent?.trim()?.toLowerCase() || ''

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
      const participant1NameOriginal = (divider.dataset.participant1Name || '').toLowerCase()
      const participant2NameOriginal = (divider.dataset.participant2Name || '').toLowerCase()

      // Get participant names from visual position (reordered for UI)
      const participant1NameVisual = participant1?.querySelector('.text-base-content.truncate')?.textContent?.trim()?.toLowerCase() || ''
      const participant2NameVisual = participant2?.querySelector('.text-base-content.truncate')?.textContent?.trim()?.toLowerCase() || ''

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

// QRCodeGenerator Hook - Generates QR code for the ticket URL
Hooks.QRCodeGenerator = {
  mounted() {
    const container = this.el
    const url = this.el.dataset.url

    // Get the full URL including domain
    const fullUrl = window.location.origin + url

    // Generate QR code
    QRCode.toCanvas(fullUrl, {
      errorCorrectionLevel: 'M',
      width: 200,
      margin: 2,
      color: {
        dark: '#000000',
        light: '#FFFFFF'
      }
    }, (error, canvas) => {
      if (error) {
        console.error('Error generating QR code:', error)
        container.innerHTML = '<p class="text-error text-sm">Error generando código QR</p>'
        return
      }

      // Clear container and add canvas
      container.innerHTML = ''
      canvas.style.display = 'block'
      container.appendChild(canvas)
    })
  }
}

// CopyToClipboard Hook - Copies text to clipboard with visual feedback
Hooks.CopyToClipboard = {
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

// ImageZoom Hook - Enables pinch-to-zoom and scroll-to-zoom for images
Hooks.ImageZoom = {
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

// ImageCropper Hook - Enables image cropping before upload
Hooks.ImageCropper = {
  mounted() {
    console.log('🎨 ImageCropper hook mounted')
    const fileInput = document.getElementById('image-file-input')

    if (!fileInput) {
      console.error('❌ File input not found')
      return
    }

    const handleFileSelect = (e) => {
      console.log('📁 File selected:', e.target.files)
      const file = e.target.files[0]
      if (!file) return

      // Validate file type
      const validTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp']
      if (!validTypes.includes(file.type)) {
        alert('Por favor selecciona una imagen válida (JPG, PNG o WEBP)')
        fileInput.value = ''
        return
      }

      // Validate file size (10MB)
      const maxSize = 10 * 1024 * 1024
      if (file.size > maxSize) {
        alert('La imagen es demasiado grande. El tamaño máximo es 10MB.')
        fileInput.value = ''
        return
      }

      console.log('✅ File valid, reading...')

      // Read file as data URL
      const reader = new FileReader()
      reader.onload = (event) => {
        console.log('📷 File loaded, showing cropper modal')
        // Create and show modal
        this.showCropperModal(event.target.result, file.name, file.type)
      }
      reader.readAsDataURL(file)
    }

    fileInput.addEventListener('change', handleFileSelect)

    // Store reference for cleanup
    this.fileInput = fileInput
    this.handleFileSelect = handleFileSelect
  },

  showCropperModal(imageSrc, fileName, fileType) {
    const fileInput = this.fileInput
    let cropper = null
    let modal = null
    let imageElement = null

    console.log('🖼️ Creating cropper modal...')

    // Get translations from data attributes (set by Gettext on the server)
    const cropTitle = this.el.dataset.i18nCropTitle || 'Recorta tu ticket'
    const confirmText = this.el.dataset.i18nConfirm || 'Confirmar'

    // Create modal
    modal = document.createElement('div')
    modal.id = 'cropper-modal'
    modal.className = 'fixed inset-0 bg-black/60 backdrop-blur-md flex items-center justify-center z-50 p-3 sm:p-4 transition-opacity'

    modal.innerHTML = `
      <div class="bg-base-300 border border-base-300 rounded-2xl shadow-2xl w-full max-w-md flex flex-col overflow-hidden transform transition-all animate-fade-in">
        <!-- Header -->
        <div class="flex items-center justify-between px-4 py-3 border-b border-base-100/10 flex-shrink-0 text-left">
          <h2 class="text-lg font-bold text-base-content">${cropTitle}</h2>
          <button id="close-cropper" class="btn btn-ghost btn-sm btn-circle">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
            </svg>
          </button>
        </div>

        <!-- Image Container -->
        <div id="cropper-container" style="max-height: 50vh; background: #000;">
          <img id="cropper-image" src="${imageSrc}" style="max-width: 100%; display: block;" />
        </div>

        <!-- Footer -->
        <div class="p-4 border-t border-base-100/10 flex-shrink-0">
          <button id="confirm-crop" class="btn btn-primary w-full shadow-lg">
            ${confirmText}
          </button>
        </div>
      </div>
    `

    document.body.appendChild(modal)
    document.body.classList.add('overflow-hidden')

    // Wait for image to load before initializing Cropper
    imageElement = document.getElementById('cropper-image')

    const initCropper = () => {
      console.log('🎨 Initializing Cropper.js...')
      cropper = new Cropper(imageElement, {
        viewMode: 1,
        dragMode: 'move',
        aspectRatio: NaN,
        autoCropArea: 0.65,
        restore: false,
        guides: true,
        center: true,
        highlight: true,
        cropBoxMovable: true,
        cropBoxResizable: true,
        toggleDragModeOnDblclick: false,
        background: true,
        modal: true,
        responsive: true,
        checkOrientation: true,
        minContainerWidth: 200,
        minContainerHeight: 200,
        ready() {
          console.log('✅ Cropper is ready!')
        }
      })
    }

    // Check if image is already loaded
    if (imageElement.complete) {
      initCropper()
    } else {
      imageElement.addEventListener('load', initCropper)
    }

    // Close button handler
    const closeButton = document.getElementById('close-cropper')

    const closeModal = () => {
      console.log('🚫 Closing cropper modal')
      if (cropper) {
        cropper.destroy()
        cropper = null
      }
      if (modal) {
        modal.remove()
        modal = null
        document.body.classList.remove('overflow-hidden')
      }
      if (fileInput) {
        fileInput.value = '' // Reset file input
      }
    }

    closeButton.addEventListener('click', closeModal)

    // Confirm button handler
    const confirmButton = document.getElementById('confirm-crop')
    confirmButton.addEventListener('click', () => {
      if (!cropper) return

      // Fixed quality at 80%
      const quality = 0.75

      console.log('✂️ Getting cropped canvas...')

      // Get cropped canvas
      const canvas = cropper.getCroppedCanvas({
        maxWidth: 2000,
        maxHeight: 2000,
        fillColor: '#fff',
        imageSmoothingEnabled: true,
        imageSmoothingQuality: 'high'
      })

      // Convert to blob with compression
      canvas.toBlob((blob) => {
        if (!blob) {
          alert('Error al procesar la imagen. Por favor intenta de nuevo.')
          return
        }

        console.log('📦 Converting to base64...')

        // Convert blob to base64
        const reader = new FileReader()
        reader.onloadend = () => {
          const base64data = reader.result

          // Calculate file size
          const sizeInBytes = Math.round((base64data.length - 'data:image/webp;base64,'.length) * 3 / 4)
          const sizeInKB = (sizeInBytes / 1024).toFixed(2)

          console.log(`✅ Imagen recortada y comprimida: ${sizeInKB}KB (calidad: ${quality * 100}%)`)

          // STEP 1: Tell backend to start processing (shows spinner)
          console.log('🔄 Sending start_processing event to show spinner...')
          this.pushEvent('start_processing', {})

          // STEP 2: Wait for LiveView to re-render with spinner, then close modal
          setTimeout(() => {
            console.log('🚪 Closing modal...')
            closeModal()

            // STEP 3: Send the actual image data
            setTimeout(() => {
              console.log('📤 Sending cropped image to backend...')
              this.pushEvent('cropped_image_ready', {
                base64: base64data.split(',')[1], // Remove data:image/webp;base64, prefix
                filename: fileName,
                content_type: 'image/webp',
                size: sizeInBytes
              })
            }, 100)
          }, 300) // Wait 300ms for LiveView to re-render with spinner
        }
        reader.readAsDataURL(blob)
      }, 'image/webp', quality)
    })
  },

  destroyed() {
    console.log('🧹 ImageCropper hook destroyed - cleaning up')
    if (this.fileInput && this.handleFileSelect) {
      this.fileInput.removeEventListener('change', this.handleFileSelect)
    }
  }
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

// Merge hooks with defensive handling (colocatedHooks may be undefined)
const allHooks = { ...(colocatedHooks || {}), ...Hooks }

const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
  hooks: allHooks,
})

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" })
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// ============= SERVICE WORKER REGISTRATION =============
// Registrar Service Worker para funcionalidad PWA
if ('serviceWorker' in navigator) {
  // Esperar a que el documento esté listo
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
      registerServiceWorker();
    });
  } else {
    registerServiceWorker();
  }
}

function registerServiceWorker() {
  navigator.serviceWorker
    .register('/service-worker.js', { scope: '/' })
    .then((registration) => {
      console.log('✓ Service Worker registrado exitosamente:', registration.scope);

      // Escuchar actualizaciones
      registration.addEventListener('updatefound', () => {
        const newWorker = registration.installing;
        if (newWorker) {
          newWorker.addEventListener('statechange', () => {
            if (newWorker.state === 'installed' && navigator.serviceWorker.controller) {
              // Notificar al usuario que hay actualización disponible
              console.log('Nueva versión disponible. Recarga la página para actualizar.');
              // Opcional: mostrar notificación al usuario
              notifyUserAboutUpdate();
            }
          });
        }
      });

      // Solicitar actualización periódicamente (cada hora)
      setInterval(() => {
        registration.update();
      }, 60 * 60 * 1000);
    })
    .catch((error) => {
      console.error('✗ Error al registrar Service Worker:', error);
    });
}

function notifyUserAboutUpdate() {
  // Crear elemento de notificación visual
  const notification = document.createElement('div');
  notification.id = 'pwa-update-notification';
  notification.innerHTML = `
    <div style="
      position: fixed;
      bottom: 20px;
      left: 50%;
      transform: translateX(-50%);
      background: linear-gradient(135deg, #7B61FF 0%, #6B51EF 100%);
      color: white;
      padding: 1rem 1.5rem;
      border-radius: 12px;
      box-shadow: 0 10px 40px rgba(123, 97, 255, 0.4);
      z-index: 10000;
      display: flex;
      align-items: center;
      gap: 1rem;
      font-family: system-ui, -apple-system, sans-serif;
      animation: slideUp 0.3s ease-out;
      max-width: calc(100vw - 40px);
    ">
      <span style="font-size: 0.95rem;">Nueva versión disponible</span>
      <button onclick="window.location.reload()" style="
        background: white;
        color: #7B61FF;
        border: none;
        padding: 0.5rem 1rem;
        border-radius: 8px;
        font-weight: 600;
        cursor: pointer;
        font-size: 0.85rem;
        white-space: nowrap;
      ">Actualizar</button>
      <button onclick="this.parentElement.parentElement.remove()" style="
        background: transparent;
        color: white;
        border: none;
        padding: 0.25rem;
        cursor: pointer;
        opacity: 0.8;
      ">✕</button>
    </div>
    <style>
      @keyframes slideUp {
        from { opacity: 0; transform: translateX(-50%) translateY(20px); }
        to { opacity: 1; transform: translateX(-50%) translateY(0); }
      }
    </style>
  `;

  // Remover notificación existente si hay una
  const existing = document.getElementById('pwa-update-notification');
  if (existing) existing.remove();

  document.body.appendChild(notification);
}

// Manejar cuando un nuevo Service Worker toma control
let refreshing = false;
navigator.serviceWorker?.addEventListener('controllerchange', () => {
  if (!refreshing) {
    refreshing = true;
    window.location.reload();
  }
});

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({ detail: reloader }) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", e => keyDown = null)
    window.addEventListener("click", e => {
      if (keyDown === "c") {
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if (keyDown === "d") {
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

