defmodule TicketSplitterWeb.TicketLive.ParticipantSelector do
  use TicketSplitterWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id}>
      <.modal
        id="participant-selector-content"
        show
        on_cancel={JS.push("close_participant_selector")}
      >
        <!-- Header (fixed) -->
        <div class="flex items-center justify-between mb-3 flex-shrink-0">
          <h2 class="text-lg font-bold text-base-content">
            {gettext("Who are you?")}
          </h2>
          <button
            phx-click="close_participant_selector"
            class="text-base-content/50 hover:text-base-content transition-colors p-1 min-w-[44px] min-h-[44px] flex items-center justify-center -mr-1"
          >
            <.icon name="hero-x-mark" class="w-5 h-5" />
          </button>
        </div>

        <p class="text-xs text-base-content/60 mb-3 flex-shrink-0">
          {gettext("Select your name if you're already in the ticket, or create a new one.")}
        </p>
        
    <!-- Existing Participants List (scrollable - limited height) -->
        <div class="space-y-2 mb-3 overflow-y-auto max-h-[380px] scrollbar-thin scrollbar-thumb-base-content/20 scrollbar-track-transparent">
          <%= for participant <- @existing_participants do %>
            <button
              phx-click="select_existing_participant"
              phx-value-name={participant.name}
              class="w-full flex items-center justify-between p-2.5 sm:p-3 bg-base-200 hover:bg-base-200/80 rounded-lg transition-colors text-left"
            >
              <div class="flex items-center gap-2 sm:gap-3 min-w-0 flex-1">
                <div
                  class="w-4 h-4 rounded-full flex-shrink-0"
                  style={"background-color: #{participant.color}"}
                >
                </div>
                <span class="font-medium text-base-content text-sm sm:text-base truncate">
                  {participant.name}
                </span>
              </div>
              <.icon name="hero-chevron-right" class="size-4 text-base-content/40 flex-shrink-0" />
            </button>
          <% end %>
        </div>
        
    <!-- Footer (fixed) -->
        <div class="flex-shrink-0">
          <!-- Divider -->
          <div class="flex items-center gap-2 my-3">
            <div class="flex-1 h-px bg-base-100/10"></div>
            <span class="text-[10px] text-base-content/40 uppercase">{gettext("or")}</span>
            <div class="flex-1 h-px bg-base-100/10"></div>
          </div>
          
    <!-- Create New Button -->
          <button
            phx-click="create_new_participant"
            class="w-full flex items-center justify-center gap-2 p-2.5 bg-primary/10 hover:bg-primary/20 border border-dashed border-primary/40 hover:border-primary rounded-lg transition-colors"
          >
            <.icon name="hero-plus" class="size-4 text-primary" />
            <span class="text-sm font-medium text-primary">{gettext("I'm new here")}</span>
          </button>
        </div>
      </.modal>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end
end
