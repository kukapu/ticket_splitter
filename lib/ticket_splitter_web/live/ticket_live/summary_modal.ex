defmodule TicketSplitterWeb.TicketLive.SummaryModal do
  use TicketSplitterWeb, :live_component

  alias TicketSplitter.Tickets

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id}>
      <.modal
        id="summary-modal-content"
        show
        on_cancel={JS.push("close_summary")}
        border_class={
          if @acting_as_participant, do: "border-2 border-warning", else: "border border-base-300"
        }
      >
        <!-- Header with tabs -->
        <div class="flex justify-between items-center mb-4">
          <div class="flex gap-1 bg-base-200 p-1 rounded-lg">
            <button
              phx-click="switch_summary_tab"
              phx-value-tab="summary"
              class={"px-3 py-1.5 text-sm font-medium rounded-md transition-colors #{if @summary_tab == "summary", do: "bg-base-100 text-primary shadow-sm", else: "text-base-content/60 hover:text-base-content"}"}
            >
              {gettext("Summary")}
            </button>
            <button
              phx-click="switch_summary_tab"
              phx-value-tab="assign"
              class={"px-3 py-1.5 text-sm font-medium rounded-md transition-colors #{if @summary_tab == "assign", do: "bg-base-100 text-primary shadow-sm", else: "text-base-content/60 hover:text-base-content"}"}
            >
              {gettext("Assign")}
            </button>
          </div>
          <button
            phx-click="close_summary"
            class="text-base-content/50 hover:text-base-content transition-colors p-1 min-w-[44px] min-h-[44px] flex items-center justify-center"
          >
            <.icon name="hero-x-mark" class="w-6 h-6" />
          </button>
        </div>

    <!-- Tab: Summary -->
        <%= if @summary_tab == "summary" do %>
          <%= if @participant_name || @acting_as_participant do %>
            <% active_name = @acting_as_participant || @participant_name

            active_multiplier =
              if @acting_as_participant, do: @acting_as_multiplier, else: @my_multiplier %>
            <div class={"mb-4 p-2 rounded-lg flex items-center justify-between #{if @acting_as_participant, do: "bg-warning/10 border border-warning/30", else: "bg-base-200"}"}>
              <div class="flex items-center gap-2 min-w-0">
                <.icon
                  name="hero-user-group"
                  class={"w-4 h-4 #{if @acting_as_participant, do: "text-warning", else: "text-primary"}"}
                />
                <div class="min-w-0">
                  <span class={"text-sm #{if @acting_as_participant, do: "text-warning", else: "text-base-content"}"}>
                    {gettext("I pay for")}
                  </span>
                  <%= if @acting_as_participant do %>
                    <div class="text-[10px] text-warning/70 truncate">{active_name}</div>
                  <% end %>
                </div>
              </div>
              <div class="flex items-center gap-1">
                <button
                  phx-click="decrement_multiplier"
                  class={"aspect-square w-6 rounded flex items-center justify-center transition-all active:scale-95 disabled:opacity-40 #{if @acting_as_participant, do: "bg-warning/20 hover:bg-warning/30 text-warning", else: "bg-secondary/25 hover:bg-secondary/40 text-secondary"}"}
                  disabled={active_multiplier <= 1}
                >
                  <span class="text-sm font-bold">−</span>
                </button>
                <span class={"min-w-[28px] text-center text-base font-bold #{if @acting_as_participant, do: "text-warning", else: "text-base-content"}"}>
                  {active_multiplier}
                </span>
                <button
                  phx-click="increment_multiplier"
                  class={"aspect-square w-6 rounded flex items-center justify-center transition-all active:scale-95 disabled:opacity-40 #{if @acting_as_participant, do: "bg-warning/20 hover:bg-warning/30 text-warning", else: "bg-primary/25 hover:bg-primary/40 text-primary"}"}
                  disabled={active_multiplier >= 10}
                >
                  <span class="text-sm font-bold">+</span>
                </button>
                <span class="text-sm text-base-content/60 ml-1">{gettext("pers.")}</span>
              </div>
            </div>
          <% end %>

    <!-- Participants List -->
          <div class="mb-4">
            <h3 class="text-sm font-semibold text-base-content/60 mb-2">{gettext("Participants")}</h3>
            <div class="space-y-1.5 max-h-[280px] overflow-y-auto pr-1 scrollbar-thin scrollbar-thumb-base-content/20 scrollbar-track-transparent">
              <%= for summary <- @participants_for_summary do %>
                <% is_current_user = summary.name == (@acting_as_participant || @participant_name) %>
                <div class="flex items-center justify-between p-2.5 bg-base-200 rounded-lg">
                  <div class="flex items-center gap-2 min-w-0 flex-1">
                    <%= if is_current_user do %>
                      <div
                        class="w-5 h-5 rounded-full flex-shrink-0 flex items-center justify-center"
                        style={"background-color: #{summary.color}"}
                      >
                        <.icon name="hero-user-solid" class="w-3 h-3 text-white" />
                      </div>
                    <% else %>
                      <div
                        class="w-3 h-3 rounded-full flex-shrink-0"
                        style={"background-color: #{summary.color}"}
                      >
                      </div>
                    <% end %>
                    <span class="font-medium text-base-content text-sm truncate">
                      {summary.name}
                      <%= if Map.get(summary, :multiplier, 1) > 1 do %>
                        <span class="text-primary font-normal"> (×{summary.multiplier})</span>
                      <% end %>
                    </span>
                  </div>
                  <span class="text-base font-semibold text-primary flex-shrink-0">
                    €{format_decimal(summary.total)}
                  </span>
                </div>
              <% end %>
            </div>
          </div>

    <!-- Totals -->
          <div class="border-t border-base-200 pt-3 space-y-1.5">
            <div class="flex justify-between text-xs">
              <span class="text-base-content/50">{gettext("Ticket total:")}</span>
              <span class="font-medium text-base-content">
                €{format_decimal(@total_ticket)}
              </span>
            </div>
            <div class="flex justify-between text-xs">
              <span class="text-base-content/50">{gettext("Total assigned:")}</span>
              <span class="font-medium text-base-content">
                €{format_decimal(@total_assigned)}
              </span>
            </div>
            <div class="flex justify-between text-sm font-bold pt-1.5 border-t border-base-200">
              <span class="text-base-content">{gettext("Pending:")}</span>
              <span class="text-primary">€{format_decimal(@pending)}</span>
            </div>
          </div>
        <% end %>

    <!-- Tab: Assign to others -->
        <%= if @summary_tab == "assign" do %>
          <div class="space-y-4">
            <!-- Current selection indicator -->
            <%= if @acting_as_participant do %>
              <div class="px-2 py-0 sm:py-2 bg-warning/10 border border-warning/30 rounded-lg flex items-center justify-between">
                <div class="flex items-center gap-2">
                  <div class="w-4 h-4 rounded-full" style={"background-color: #{@acting_as_color}"}>
                  </div>
                  <span class="text-sm font-medium text-base-content">
                    {gettext("Assigning to:")} <strong>{@acting_as_participant}</strong>
                  </span>
                </div>
                <button
                  phx-click="clear_acting_as"
                  class="text-xs text-warning hover:text-warning/80 font-medium"
                >
                  {gettext("Clear")}
                </button>
              </div>
            <% else %>
              <p class="text-sm text-base-content/60">
                {gettext("Select a person to assign items on their behalf")}
              </p>
            <% end %>

    <!-- Participants selector (bigger buttons) -->
            <div class="space-y-2 max-h-[280px] overflow-y-auto pr-1 scrollbar-thin scrollbar-thumb-base-content/20 scrollbar-track-transparent">
              <!-- Return to self -->
              <button
                phx-click="clear_acting_as"
                class={"w-full flex items-center gap-3 p-3 rounded-lg border transition-colors text-left #{if !@acting_as_participant, do: "bg-primary/10 border-primary/30", else: "bg-base-200 border-base-300 hover:border-primary/30"}"}
              >
                <div
                  class="w-5 h-5 rounded-full flex-shrink-0"
                  style={"background-color: #{if @participant_name, do: @participant_color, else: "#cbd5e1"}"}
                >
                </div>
                <span class="text-sm font-medium text-base-content flex-1 truncate">
                  {if @participant_name, do: @participant_name, else: gettext("Me")}
                </span>
                <span class="text-xs text-primary font-medium">{gettext("(me)")}</span>
                <%= if !@acting_as_participant do %>
                  <.icon name="hero-check-circle-solid" class="w-5 h-5 text-primary flex-shrink-0" />
                <% end %>
              </button>

    <!-- Other participants -->
              <% existing_participants = Tickets.get_ticket_participants(@ticket.id) %>
              <%= for participant <- existing_participants do %>
                <%= if participant.name != @participant_name do %>
                  <button
                    phx-click="set_acting_as"
                    phx-value-name={participant.name}
                    class={"w-full flex items-center gap-3 p-3 rounded-lg border transition-colors text-left #{if @acting_as_participant == participant.name, do: "bg-primary/10 border-primary/30", else: "bg-base-200 border-base-300 hover:border-primary/30"}"}
                  >
                    <div
                      class="w-5 h-5 rounded-full flex-shrink-0"
                      style={"background-color: #{participant.color}"}
                    >
                    </div>
                    <span class="text-sm font-medium text-base-content flex-1 truncate">
                      {participant.name}
                    </span>
                    <%= if @acting_as_participant == participant.name do %>
                      <.icon
                        name="hero-check-circle-solid"
                        class="w-5 h-5 text-primary flex-shrink-0"
                      />
                    <% end %>
                  </button>
                <% end %>
              <% end %>
            </div>

    <!-- Add new person (outside the selector) -->
            <div class="pt-3 border-t border-base-200">
              <p class="text-xs text-base-content/50 mb-2">{gettext("Add new person")}</p>
              <form phx-submit="create_ghost_participant" class="flex gap-2">
                <input
                  type="text"
                  name="name"
                  placeholder={gettext("Name...")}
                  class="flex-1 px-3 py-2.5 text-sm bg-base-200 border border-base-300 rounded-lg focus:ring-2 focus:ring-primary/50 focus:border-primary"
                />
                <button
                  type="submit"
                  class="px-4 py-2.5 bg-primary hover:bg-primary/90 text-primary-content rounded-lg font-medium text-sm transition-colors"
                >
                  {gettext("Add")}
                </button>
              </form>
            </div>
          </div>
        <% end %>
      </.modal>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  # Helper function for formatting decimals
  defp format_decimal(decimal) do
    decimal
    |> Decimal.round(2)
    |> Decimal.to_string()
  end
end
