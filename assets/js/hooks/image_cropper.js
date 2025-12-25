import Cropper from "cropperjs"
import "cropperjs/dist/cropper.css"

// ImageCropper Hook - Enables image cropping before upload
export const ImageCropper = {
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
