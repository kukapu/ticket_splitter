defmodule TicketSplitterWeb.HomeLive.HistorySection do
  @moduledoc """
  LiveComponent for displaying ticket history.
  """
  use TicketSplitterWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mb-6">
      <%= if @show_history and length(@ticket_history) > 0 do %>
        <div class="card bg-base-100 shadow-xl mb-4">
          <div class="card-body p-4">
            <div class="flex justify-between items-center mb-2">
              <h3 class="card-title text-lg">{gettext("Recent Tickets")}</h3>
              <button
                phx-click="toggle_history"
                class="btn btn-ghost btn-sm btn-circle"
                aria-label={gettext("Hide history")}
              >
                ✕
              </button>
            </div>

            <div class="space-y-2 max-h-64 overflow-y-auto">
              <%= for ticket <- @ticket_history do %>
                <div class="flex items-center justify-between p-3 bg-base-200 rounded-lg hover:bg-base-300 transition-colors">
                  <a
                    href={~p"/#{@locale}/tickets/#{ticket["id"]}"}
                    class="flex-1 text-sm font-medium hover:text-primary"
                  >
                    {ticket["merchant_name"] || gettext("Ticket")} #{String.slice(
                      ticket["id"],
                      0..7
                    )}
                  </a>

                  <button
                    phx-click="ask_delete"
                    phx-value-id={ticket["id"]}
                    class="btn btn-ghost btn-xs btn-circle text-error hover:bg-error hover:text-error-content"
                    aria-label={gettext("Delete")}
                  >
                    🗑️
                  </button>
                </div>
              <% end %>
            </div>
          </div>
        </div>

        <%= if @ticket_to_delete do %>
          <div class="modal modal-open">
            <div class="modal-box">
              <h3 class="font-bold text-lg">{gettext("Confirm deletion")}</h3>
              <p class="py-4">
                {gettext("Are you sure you want to delete this ticket from history?")}
              </p>
              <div class="modal-action">
                <button phx-click="cancel_delete" class="btn">
                  {gettext("Cancel")}
                </button>
                <button
                  phx-click="delete_ticket"
                  phx-value-id={@ticket_to_delete}
                  class="btn btn-error"
                >
                  {gettext("Delete")}
                </button>
              </div>
            </div>
          </div>
        <% end %>
      <% else %>
        <%= if !@processing do %>
          <button
            phx-click="toggle_history"
            class="btn btn-ghost btn-sm w-full mb-4"
            disabled={length(@ticket_history) == 0}
          >
            📋 {gettext("Show recent tickets")}
            <%= if length(@ticket_history) > 0 do %>
              ({length(@ticket_history)})
            <% end %>
          </button>
        <% end %>
      <% end %>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:locale, fn -> "en" end)}
  end
end
