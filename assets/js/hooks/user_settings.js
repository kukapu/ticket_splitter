// UserSettings Hook - Manages user settings in localStorage (for header user modal)
export const UserSettings = {
  mounted() {
    // Load the current user name and send to LiveView
    this.loadUserName()

    // Handle save event from LiveView
    this.handleEvent("save_user_name", ({ name }) => {
      const normalizedName = name ? name.trim() : ""
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
