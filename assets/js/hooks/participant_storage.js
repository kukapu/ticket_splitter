// ParticipantStorage Hook - Manages participant name in localStorage
export const ParticipantStorage = {
  mounted() {
    this.sendParticipantName()

    this.handleEvent("save_participant_name", ({ name }) => {
      localStorage.setItem('participant_name', name || "")
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

  // Reconnected callback - called when LiveView reconnects after disconnect
  reconnected() {
    console.log('🔄 LiveView reconnected, restoring participant name...')
    this.sendParticipantName()
  },

  destroyed() {
    // Clean up event listener
    if (this.handleUserNameChange) {
      document.removeEventListener('user-name-change-request', this.handleUserNameChange)
    }
  },

  sendParticipantName() {
    const name = localStorage.getItem('participant_name')
    console.log('📤 Sending participant_name_from_storage:', name || "(empty)")
    this.pushEvent("participant_name_from_storage", { name: name || "" })
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
