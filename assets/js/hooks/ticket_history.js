// TicketHistory Hook - Manages ticket history display on home page
export const TicketHistory = {
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
