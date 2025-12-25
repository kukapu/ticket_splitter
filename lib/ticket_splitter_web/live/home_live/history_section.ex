defmodule TicketSplitterWeb.HomeLive.HistorySection do
  use TicketSplitterWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id}>
      <%= if !@processing do %>
      <div id="ticket-history-container" class="mb-3 relative">
        <div class="bg-base-200 rounded-3xl home-card-shadow border border-base-300 relative z-10">
          <!-- History Header Button -->
          <button
            phx-click="toggle_history"
            class="w-full p-4 hover:bg-base-300/50 transition-all duration-200 group rounded-3xl"
          >
            <div class="flex justify-between items-center">
              <div class="flex items-center gap-3">
                <div class="w-10 h-10 bg-secondary/20 rounded-full flex items-center justify-center">
                  <.icon name="hero-clock" class="w-5 h-5 text-secondary" />
                </div>
                <div class="text-left">
                  <h3 class="text-base font-semibold text-base-content">
                    {gettext("Recent tickets")}
                  </h3>
                  <%= if @ticket_history != [] do %>
                    <p class="text-xs text-base-content/50">
                      {ngettext(
                        "%{count} saved ticket",
                        "%{count} saved tickets",
                        length(@ticket_history),
                        count: length(@ticket_history)
                      )}
                    </p>
                  <% else %>
                    <p class="text-xs text-base-content/50">
                      {gettext("No tickets saved yet")}
                    </p>
                  <% end %>
                </div>
              </div>
              <.icon
                name="hero-chevron-down"
                class={"w-5 h-5 text-base-content/50 transition-transform duration-200 #{if @show_history, do: "rotate-180"}"}
              />
            </div>
          </button>

          <!-- Expandable History List -->
          <%= if @show_history do %>
            <div class="absolute top-full left-0 right-0 mt-2 bg-base-200 border border-base-300 rounded-3xl home-card-shadow z-20 animate-[fadeIn_0.2s_ease-in-out]">
              <div class="max-h-[400px] overflow-y-auto p-3 space-y-2">
                <%= if @ticket_history == [] do %>
                  <!-- Empty State -->
                  <div class="text-center py-8">
                    <div class="mx-auto w-16 h-16 bg-base-300 rounded-full flex items-center justify-center mb-3">
                      <.icon name="hero-document-text" class="w-8 h-8 text-base-content/30" />
                    </div>
                    <p class="text-sm text-base-content/50">
                      {gettext("No recent tickets")}
                    </p>
                    <p class="text-xs text-base-content/40 mt-2">
                      {gettext("Upload a ticket and participate to start your history")}
                    </p>
                  </div>
                <% else %>
                  <!-- History Items -->
                  <%= for ticket <- @ticket_history do %>
                    <div class="group flex items-stretch bg-base-100 rounded-xl transition-all duration-200 border border-base-300 hover:border-primary/50 hover:shadow-md overflow-hidden">
                      <button
                        type="button"
                        phx-click="ask_delete"
                        phx-value-id={ticket["id"]}
                        class="flex items-center justify-center px-3 sm:px-4 text-base-content/20 hover:text-error hover:bg-error/10 transition-colors border-r border-base-200"
                        title={gettext("Delete from history")}
                      >
                        <.icon name="hero-trash" class="w-4 h-4 sm:w-5 sm:h-5" />
                      </button>

                      <a
                        href={ticket["url"]}
                        class="flex-1 block p-3 min-w-0 hover:bg-base-200/50 transition-colors"
                      >
                        <div class="flex items-center justify-between gap-3">
                          <div class="flex-1 min-w-0">
                            <h4 class="text-sm font-semibold text-base-content truncate group-hover:text-primary transition-colors">
                              {ticket["merchant_name"] || gettext("Unnamed ticket")}
                            </h4>
                            <%= if ticket["date"] do %>
                              <div class="flex items-center gap-1.5 mt-1">
                                <.icon
                                  name="hero-calendar-days"
                                  class="w-3 h-3 text-base-content/40"
                                />
                                <time class="text-xs text-base-content/50">
                                  <%= case Date.from_iso8601(ticket["date"]) do %>
                                    <% {:ok, date} -> %>
                                      {Calendar.strftime(date, "%d/%m/%Y")}
                                    <% _ -> %>
                                      {ticket["date"]}
                                  <% end %>
                                </time>
                              </div>
                            <% end %>
                          </div>
                          <div class="flex-shrink-0">
                            <.icon
                              name="hero-chevron-right"
                              class="w-5 h-5 text-base-content/30 group-hover:text-primary group-hover:translate-x-1 transition-all"
                            />
                          </div>
                        </div>
                      </a>
                    </div>
                  <% end %>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
      </div>

      <!-- Delete Confirmation Modal -->
      <.modal
        :if={@ticket_to_delete}
        id="delete-ticket-modal"
        show
        on_cancel={JS.push("cancel_delete")}
      >
        <h2 class="text-lg sm:text-xl font-bold text-base-content mb-3 sm:mb-4">
          {gettext("Delete ticket")}
        </h2>
        <p class="text-sm sm:text-base text-base-content mb-4 sm:mb-6">
          {gettext(
            "Are you sure you want to delete this ticket from history? This action cannot be undone."
          )}
        </p>
        <div class="flex flex-col xs:flex-row gap-2.5 sm:gap-3 justify-end">
          <button
            phx-click="cancel_delete"
            class="px-6 py-3 bg-base-200 text-base-content rounded-lg hover:bg-base-200/80 transition-colors font-medium min-h-[44px] order-2 xs:order-1"
          >
            {gettext("Cancel")}
          </button>
          <button
            phx-click="delete_ticket"
            phx-value-id={@ticket_to_delete}
            class="px-6 py-3 bg-primary text-primary-content rounded-lg hover:bg-primary/90 transition-colors font-medium shadow-lg min-h-[44px] order-1 xs:order-2"
          >
            {gettext("Confirm")}
          </button>
        </div>
      </.modal>
    <% end %>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end
end
