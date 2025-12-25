import QRCode from "qrcode"

// QRCodeGenerator Hook - Generates QR code for the ticket URL
export const QRCodeGenerator = {
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
