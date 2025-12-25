defmodule TicketSplitterWeb.HomeLive.UploadSection do
  use TicketSplitterWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id}>
      <%= if @processing do %>
        <!-- Processing Loader -->
        <div class="text-center py-12">
          <div class="inline-block w-16 h-16 border-4 border-base-300 border-t-primary rounded-full animate-spin mb-6">
          </div>
          <p class="text-base-content/70 text-lg font-medium animate-pulse">
            {gettext("Analyzing your ticket...")}
          </p>
        </div>
      <% else %>
        <!-- Upload Area -->
        <div class="bg-base-200 rounded-3xl home-card-shadow border border-base-300 overflow-hidden">
          <div class="p-8">
            <!-- Simple Upload Button -->
            <div class="text-center space-y-6">
              <div class="mx-auto w-24 h-24 bg-primary rounded-full flex items-center justify-center shadow-lg">
                <.icon name="hero-camera" class="w-12 h-12 text-primary-content" />
              </div>

              <div>
                <h3 class="text-xl font-semibold text-base-content mb-2">
                  {gettext("Upload your ticket")}
                </h3>
                <p class="text-base-content/50 text-sm">
                  {gettext("JPG, PNG or WEBP (max. 10MB)")}
                </p>
              </div>

              <!-- Upload Buttons -->
              <div class="space-y-3">
                <button
                  type="button"
                  class="w-full px-6 py-4 bg-primary text-primary-content font-semibold rounded-xl hover:bg-primary/90 transition-all duration-200 shadow-lg hover:shadow-xl transform hover:scale-105"
                  onclick="document.getElementById('image-file-input').removeAttribute('capture'); document.getElementById('image-file-input').click();"
                >
                  <.icon name="hero-photo" class="w-5 h-5 inline mr-2" /> {gettext("Select image")}
                </button>

                <!-- Camera Button (Mobile) -->
                <button
                  type="button"
                  class="w-full px-6 py-4 bg-base-300 text-base-content font-semibold rounded-xl hover:bg-base-300/80 transition-all duration-200 shadow-lg sm:hidden"
                  onclick="document.getElementById('image-file-input').setAttribute('capture', 'environment'); document.getElementById('image-file-input').click();"
                >
                  <.icon name="hero-camera" class="w-5 h-5 inline mr-2" /> {gettext("Take photo")}
                </button>
              </div>
            </div>
          </div>
        </div>
      <% end %>

      <!-- Error Display -->
      <%= if @error do %>
        <div class="mt-6 bg-error/20 border border-error rounded-xl p-6 text-center">
          <div class="mx-auto w-12 h-12 bg-error rounded-full flex items-center justify-center mb-3">
            <.icon name="hero-exclamation-triangle" class="w-6 h-6 text-error-content" />
          </div>
          <h3 class="text-lg font-semibold text-error-content mb-2">{gettext("Error")}</h3>
          <p class="text-error-content/80 text-sm mb-4">{@error}</p>
          <button
            phx-click="clear-result"
            class="px-4 py-2 bg-error text-error-content font-medium rounded-lg hover:bg-error/80 transition-colors duration-200"
          >
            {gettext("Retry")}
          </button>
        </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end
end
