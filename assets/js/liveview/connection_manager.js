/**
 * LiveView Connection Manager
 *
 * Manages LiveView connection lifecycle, optimizing reconnection behavior
 * for PWA environments and providing connection state tracking.
 */

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
  if (tries <= 3) {
    return 0  // Instant reconnection for first 3 attempts
  } else if (tries <= 5) {
    return 100  // 100ms for attempts 4-5
  } else {
    // Exponential backoff for persistent connection issues
    return [1000, 2000, 5000, 10000][Math.min(tries - 6, 3)]
  }
}

/**
 * Connection state tracker
 */
class ConnectionTracker {
  constructor() {
    this.disconnectedAt = null
    this.isQuickReconnection = false
  }

  /**
   * Called when LiveView disconnects
   */
  onDisconnected() {
    this.disconnectedAt = Date.now()
    this.isQuickReconnection = false
  }

  /**
   * Called when LiveView reconnects
   * Logs quick reconnections for debugging
   */
  onConnected() {
    if (this.disconnectedAt) {
      const disconnectDuration = Date.now() - this.disconnectedAt
      this.isQuickReconnection = disconnectDuration < 1000  // Less than 1 second

      if (this.isQuickReconnection) {
        console.log(`✅ Quick reconnection successful (${disconnectDuration}ms)`)
      } else {
        console.log(`🔄 Reconnected after ${disconnectDuration}ms`)
      }

      this.disconnectedAt = null
    }
  }

  /**
   * Returns whether the last reconnection was quick
   * @returns {boolean}
   */
  wasQuickReconnection() {
    return this.isQuickReconnection
  }
}

/**
 * Initialize connection tracking for LiveView
 * Sets up event listeners for connection state changes
 */
export function initializeConnectionTracking() {
  const tracker = new ConnectionTracker()

  // Handle LiveView connection events to track reconnections
  window.addEventListener("phx:disconnected", () => {
    tracker.onDisconnected()
  })

  window.addEventListener("phx:connected", () => {
    tracker.onConnected()
  })

  return tracker
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
