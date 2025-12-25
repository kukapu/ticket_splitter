defmodule TicketSplitterWeb.HomeLive.UploadSection do
  @moduledoc """
  LiveComponent for uploading and processing ticket images.
  """
  use TicketSplitterWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <%= if @processing do %>
        <div class="card bg-base-100 shadow-xl">
          <div class="card-body items-center text-center">
            <div class="loading loading-spinner loading-lg text-primary"></div>
            <p class="text-lg font-semibold mt-4">{gettext("Processing your ticket...")}</p>
            <p class="text-sm text-base-content/70">
              {gettext("This may take a few seconds")}
            </p>
          </div>
        </div>
      <% else %>
        <%= if @error do %>
          <div class="alert alert-error mb-4">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="stroke-current shrink-0 h-6 w-6"
              fill="none"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z"
              />
            </svg>
            <span><%= @error %></span>
            <button phx-click="clear-result" class="btn btn-sm btn-ghost">✕</button>
          </div>
        <% end %>

        <div class="card bg-base-100 shadow-xl hover:shadow-2xl transition-shadow">
          <div class="card-body items-center text-center">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-20 w-20 text-primary mb-4"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"
              />
            </svg>

            <h2 class="card-title text-2xl mb-2">
              {gettext("Upload your ticket")}
            </h2>

            <p class="text-base-content/70 mb-6">
              {gettext("Take a photo or upload an image of your receipt")}
            </p>

            <button
              class="btn btn-primary btn-lg"
              onclick="document.getElementById('image-file-input').click()"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-6 w-6"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M3 9a2 2 0 012-2h.93a2 2 0 001.664-.89l.812-1.22A2 2 0 0110.07 4h3.86a2 2 0 011.664.89l.812 1.22A2 2 0 0018.07 7H19a2 2 0 012 2v9a2 2 0 01-2 2H5a2 2 0 01-2-2V9z"
                />
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M15 13a3 3 0 11-6 0 3 3 0 016 0z"
                />
              </svg>
              {gettext("Choose image")}
            </button>

            <p class="text-xs text-base-content/50 mt-4">
              {gettext("Supports JPG, PNG, WEBP (max 10MB)")}
            </p>
          </div>
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
