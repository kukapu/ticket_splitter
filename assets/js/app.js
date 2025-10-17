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
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/ticket_splitter"
import topbar from "../vendor/topbar"

// Custom Hooks
const Hooks = {}

// ParticipantStorage Hook - Manages participant name in localStorage
Hooks.ParticipantStorage = {
  mounted() {
    const name = localStorage.getItem('participant_name')
    this.pushEvent("participant_name_from_storage", { name: name || "" })

    this.handleEvent("save_participant_name", ({ name }) => {
      localStorage.setItem('participant_name', name)
    })
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

    const updateSplit = (clientX) => {
      const deltaX = clientX - startX
      const percentageChange = (deltaX / containerWidth) * 100
      let newPercentage = startPercentage + percentageChange

      // Clamp between 5% and 95%
      newPercentage = Math.max(5, Math.min(95, newPercentage))

      // Update visual positions
      divider.style.left = `${newPercentage}%`

      // Find and update participant sections
      const participant1 = container.querySelector('[id^="participant-"][id$="-0"]')
      const participant2 = container.querySelector('[id^="participant-"][id$="-1"]')

      if (participant1 && participant2) {
        participant1.style.width = `${newPercentage}%`
        participant2.style.width = `${100 - newPercentage}%`

        // Update percentage displays
        const percent1Display = participant1.querySelector('.percentage-display')
        const percent2Display = participant2.querySelector('.percentage-display')

        if (percent1Display) percent1Display.textContent = `${Math.round(newPercentage)}%`
        if (percent2Display) percent2Display.textContent = `${Math.round(100 - newPercentage)}%`
      }

      return Math.round(newPercentage)
    }

    const handleStart = (e) => {
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

      const newPercentage = updateSplit(clientX)

      // Throttle updates to LiveView
      if (!this.updateTimeout) {
        this.updateTimeout = setTimeout(() => {
          this.pushEvent("adjust_split_percentage", {
            group_id: divider.dataset.groupId,
            product_id: divider.dataset.productId,
            participant1_percentage: newPercentage,
            participant2_percentage: 100 - newPercentage
          })
          this.updateTimeout = null
        }, 100) // Update every 100ms while dragging
      }
    }

    const handleEnd = (e) => {
      if (!isDragging) return

      e.preventDefault()
      e.stopPropagation()

      isDragging = false
      divider.style.cursor = 'ew-resize'
      divider.classList.remove('dragging')

      // Final update
      if (this.updateTimeout) {
        clearTimeout(this.updateTimeout)
        this.updateTimeout = null
      }

      const clientX = e.type.includes('touch') ?
        e.changedTouches[0].clientX :
        divider.getBoundingClientRect().left + (divider.offsetWidth / 2)
      const finalPercentage = updateSplit(clientX)

      this.pushEvent("adjust_split_percentage", {
        group_id: divider.dataset.groupId,
        product_id: divider.dataset.productId,
        participant1_percentage: finalPercentage,
        participant2_percentage: 100 - finalPercentage
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

    // Cleanup on unmount
    this.handleDestroy = () => {
      document.removeEventListener('mousemove', handleMove)
      document.removeEventListener('mouseup', handleEnd)
      document.removeEventListener('touchmove', handleMove)
      document.removeEventListener('touchend', handleEnd)
      container.removeEventListener('click', handleContainerClick, true)
    }
  },

  destroyed() {
    if (this.handleDestroy) {
      this.handleDestroy()
    }
  }
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, ...Hooks},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
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
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

