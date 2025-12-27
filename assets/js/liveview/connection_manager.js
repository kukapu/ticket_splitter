/**
 * LiveView Connection Manager
 *
 * Manages LiveView connection lifecycle, optimizing reconnection behavior
 * for PWA environments and providing robust recovery mechanisms.
 * 
 * Key features:
 * - Page Visibility API detection for background/foreground transitions
 * - Automatic reconnection with exponential backoff
 * - Recovery reload if reconnection fails after extended time
 * - Suppression of error toasts during quick reconnections
 */

// Configuration constants
const CONFIG = {
  // Number of instant reconnection attempts before applying delays
  INSTANT_RECONNECT_ATTEMPTS: 3,
  // Maximum time (ms) to wait for reconnection before forcing a reload
  MAX_RECONNECT_WAIT_MS: 15000,
  // Time (ms) a reconnection must take to be considered "quick"
  QUICK_RECONNECTION_THRESHOLD_MS: 2000,
  // Minimum time (ms) page must be hidden before we consider it a "long" disconnect
  LONG_DISCONNECT_THRESHOLD_MS: 30000,
  // Delay (ms) before checking connection after page becomes visible
  VISIBILITY_CHECK_DELAY_MS: 500,
  // Maximum attempts before showing recovery UI
  MAX_ATTEMPTS_BEFORE_RECOVERY: 10,
}

/**
 * Calculates optimal reconnection delay based on attempt number.
 * Optimized for PWA reconnections with instant first attempts.
 *
 * @param {number} tries - Number of reconnection attempts
 * @returns {number} Delay in milliseconds before next reconnection attempt
 */
export function getReconnectionDelay(tries) {
  // For PWA reconnections (first 3 tries), reconnect immediately
  // This prevents the error toast from showing on quick reconnections
  if (tries <= CONFIG.INSTANT_RECONNECT_ATTEMPTS) {
    return 0  // Instant reconnection for first attempts
  } else if (tries <= 5) {
    return 100  // 100ms for attempts 4-5
  } else if (tries <= 8) {
    // Gradual backoff for attempts 6-8
    return [500, 1000, 2000][tries - 6]
  } else {
    // Exponential backoff for persistent connection issues
    return Math.min(5000, 1000 * Math.pow(1.5, tries - 8))
  }
}

/**
 * Connection state tracker with visibility awareness
 */
class ConnectionManager {
  constructor() {
    this.disconnectedAt = null
    this.hiddenAt = null
    this.isQuickReconnection = false
    this.reconnectAttempts = 0
    this.recoveryTimeoutId = null
    this.isConnected = false
    this.liveSocket = null
    this.lastSuccessfulMount = Date.now()
  }

  /**
   * Initialize the connection manager with a LiveSocket reference
   * @param {LiveSocket} liveSocket - The Phoenix LiveSocket instance
   */
  init(liveSocket) {
    this.liveSocket = liveSocket
    this.setupEventListeners()
    this.setupVisibilityHandler()
    console.log('🔌 ConnectionManager initialized')
  }

  /**
   * Set up LiveView connection event listeners
   */
  setupEventListeners() {
    // Track disconnection
    window.addEventListener("phx:disconnected", () => {
      this.onDisconnected()
    })

    // Track connection
    window.addEventListener("phx:connected", () => {
      this.onConnected()
    })

    // Track page loading completion (indicates successful mount)
    window.addEventListener("phx:page-loading-stop", () => {
      this.lastSuccessfulMount = Date.now()
      this.reconnectAttempts = 0
    })
  }

  /**
   * Set up Page Visibility API handler for background/foreground detection
   */
  setupVisibilityHandler() {
    document.addEventListener("visibilitychange", () => {
      if (document.hidden) {
        this.onPageHidden()
      } else {
        this.onPageVisible()
      }
    })

    // Also handle window focus/blur for additional reliability
    window.addEventListener("focus", () => {
      this.onPageVisible()
    })

    // Handle online/offline events
    window.addEventListener("online", () => {
      console.log('🌐 Network online detected')
      this.attemptReconnection()
    })
  }

  /**
   * Called when the page becomes hidden (background)
   */
  onPageHidden() {
    this.hiddenAt = Date.now()
    console.log('📱 Page hidden (background)')

    // Cancel any pending recovery timeout
    this.cancelRecoveryTimeout()
  }

  /**
   * Called when the page becomes visible (foreground)
   */
  onPageVisible() {
    const wasHiddenFor = this.hiddenAt ? Date.now() - this.hiddenAt : 0
    console.log(`📱 Page visible after ${wasHiddenFor}ms`)

    this.hiddenAt = null

    // Give the socket a moment to attempt automatic reconnection
    setTimeout(() => {
      this.checkConnectionAndRecover(wasHiddenFor)
    }, CONFIG.VISIBILITY_CHECK_DELAY_MS)
  }

  /**
   * Check connection status and initiate recovery if needed
   * @param {number} wasHiddenFor - How long the page was hidden
   */
  checkConnectionAndRecover(wasHiddenFor) {
    if (!this.liveSocket) return

    const socketConnected = this.liveSocket.isConnected()

    if (!socketConnected) {
      console.log('⚠️ Socket disconnected after returning from background')

      // If was hidden for a long time, we may need a full reload
      if (wasHiddenFor > CONFIG.LONG_DISCONNECT_THRESHOLD_MS) {
        console.log('🔄 Long disconnect detected, attempting reconnection with fallback...')
        this.attemptReconnectionWithRecovery()
      } else {
        // Short disconnect - just try to reconnect
        this.attemptReconnection()
      }
    } else {
      // Socket says it's connected, but verify the LiveView is actually mounted
      // by checking if we can interact with it
      this.verifyLiveViewMounted()
    }
  }

  /**
   * Verify that LiveView is actually mounted and responsive
   */
  verifyLiveViewMounted() {
    // Check if there's any phx-connected element visible
    // If the page is in an error state, we might see phx-error classes
    const hasError = document.querySelector('[phx-error]') !== null ||
      document.querySelector('.phx-error') !== null

    if (hasError) {
      console.log('⚠️ LiveView error state detected, initiating recovery...')
      this.initiateRecovery()
      return
    }

    // Check if the main content is rendered (not blank/black screen)
    const mainContent = document.querySelector('main')
    if (mainContent && mainContent.children.length === 0) {
      console.log('⚠️ Empty main content detected, initiating recovery...')
      this.initiateRecovery()
      return
    }

    console.log('✅ LiveView appears healthy after visibility change')
  }

  /**
   * Attempt to reconnect the socket
   */
  attemptReconnection() {
    if (!this.liveSocket) return

    this.reconnectAttempts++
    console.log(`🔄 Attempting reconnection (attempt ${this.reconnectAttempts})`)

    try {
      // Force socket to reconnect
      if (!this.liveSocket.isConnected()) {
        this.liveSocket.connect()
      }
    } catch (e) {
      console.error('❌ Error during reconnection attempt:', e)
    }
  }

  /**
   * Attempt reconnection with a recovery fallback
   */
  attemptReconnectionWithRecovery() {
    this.attemptReconnection()

    // Set up recovery timeout
    this.scheduleRecoveryTimeout()
  }

  /**
   * Schedule a recovery timeout that will reload the page if reconnection fails
   */
  scheduleRecoveryTimeout() {
    this.cancelRecoveryTimeout()

    this.recoveryTimeoutId = setTimeout(() => {
      if (!this.liveSocket?.isConnected() || this.reconnectAttempts >= CONFIG.MAX_ATTEMPTS_BEFORE_RECOVERY) {
        console.log('⏰ Recovery timeout reached, reloading page...')
        this.initiateRecovery()
      }
    }, CONFIG.MAX_RECONNECT_WAIT_MS)
  }

  /**
   * Cancel any pending recovery timeout
   */
  cancelRecoveryTimeout() {
    if (this.recoveryTimeoutId) {
      clearTimeout(this.recoveryTimeoutId)
      this.recoveryTimeoutId = null
    }
  }

  /**
   * Initiate page recovery (reload)
   */
  initiateRecovery() {
    this.cancelRecoveryTimeout()

    console.log('🔄 Initiating page recovery...')

    // Store that we're recovering to prevent loops
    const recoveryCount = parseInt(sessionStorage.getItem('lv_recovery_count') || '0')

    if (recoveryCount >= 3) {
      // Too many recovery attempts - show error to user instead of looping
      console.error('❌ Too many recovery attempts, showing error state')
      sessionStorage.removeItem('lv_recovery_count')
      this.showRecoveryError()
      return
    }

    sessionStorage.setItem('lv_recovery_count', String(recoveryCount + 1))

    // Clear recovery count after successful load (set up listener first)
    window.addEventListener('phx:page-loading-stop', () => {
      sessionStorage.removeItem('lv_recovery_count')
    }, { once: true })

    // Perform reload
    window.location.reload()
  }

  /**
   * Show an error message when recovery fails repeatedly
   */
  showRecoveryError() {
    const errorDiv = document.createElement('div')
    errorDiv.id = 'connection-recovery-error'
    errorDiv.innerHTML = `
      <div style="
        position: fixed;
        inset: 0;
        display: flex;
        align-items: center;
        justify-content: center;
        background: rgba(0, 0, 0, 0.8);
        z-index: 99999;
        padding: 1rem;
      ">
        <div style="
          background: oklch(var(--color-base-200, 0.2 0 0));
          padding: 2rem;
          border-radius: 1rem;
          max-width: 400px;
          text-align: center;
          color: oklch(var(--color-base-content, 0.9 0 0));
        ">
          <div style="font-size: 3rem; margin-bottom: 1rem;">📶</div>
          <h2 style="font-size: 1.25rem; font-weight: bold; margin-bottom: 0.5rem;">
            Connection Problem
          </h2>
          <p style="margin-bottom: 1.5rem; opacity: 0.8;">
            Unable to reconnect. Please check your internet connection.
          </p>
          <button onclick="window.location.reload()" style="
            background: oklch(var(--color-primary, 0.6 0.2 260));
            color: white;
            border: none;
            padding: 0.75rem 1.5rem;
            border-radius: 0.5rem;
            font-weight: 600;
            cursor: pointer;
          ">
            Retry
          </button>
        </div>
      </div>
    `

    // Remove existing error if any
    document.getElementById('connection-recovery-error')?.remove()
    document.body.appendChild(errorDiv)
  }

  /**
   * Called when LiveView disconnects
   */
  onDisconnected() {
    const wasConnected = this.isConnected
    this.disconnectedAt = Date.now()
    this.isQuickReconnection = false
    this.isConnected = false

    if (wasConnected) {
      console.log('⚡ LiveView disconnected')

      // Only schedule recovery if page is visible
      if (!document.hidden) {
        this.scheduleRecoveryTimeout()
      }
    }
  }

  /**
   * Called when LiveView reconnects
   */
  onConnected() {
    const disconnectDuration = this.disconnectedAt ? Date.now() - this.disconnectedAt : 0
    this.isQuickReconnection = disconnectDuration < CONFIG.QUICK_RECONNECTION_THRESHOLD_MS
    this.isConnected = true
    this.reconnectAttempts = 0

    // Cancel recovery timeout since we're connected
    this.cancelRecoveryTimeout()

    // Remove any recovery error overlay
    document.getElementById('connection-recovery-error')?.remove()

    if (this.disconnectedAt) {
      if (this.isQuickReconnection) {
        console.log(`✅ Quick reconnection successful (${disconnectDuration}ms)`)
      } else {
        console.log(`🔄 Reconnected after ${disconnectDuration}ms`)
      }
    } else {
      console.log('✅ LiveView connected')
    }

    this.disconnectedAt = null

    // Clear any recovery count on successful connection
    sessionStorage.removeItem('lv_recovery_count')
  }

  /**
   * Returns whether the last reconnection was quick
   * @returns {boolean}
   */
  wasQuickReconnection() {
    return this.isQuickReconnection
  }
}

// Singleton instance
const connectionManager = new ConnectionManager()

/**
 * Initialize connection tracking for LiveView
 * @param {LiveSocket} liveSocket - The Phoenix LiveSocket instance
 */
export function initializeConnectionTracking(liveSocket) {
  connectionManager.init(liveSocket)
  return connectionManager
}

/**
 * Get LiveSocket configuration options optimized for PWA
 *
 * @param {Object} baseOptions - Base configuration options
 * @returns {Object} Enhanced configuration with reconnection optimization
 */
export function getOptimizedLiveSocketConfig(baseOptions = {}) {
  return {
    ...baseOptions,
    // Optimize reconnection for PWA - make first attempts instant
    reconnectAfterMs: getReconnectionDelay,
  }
}

// Export the connection manager for direct access if needed
export { connectionManager }
