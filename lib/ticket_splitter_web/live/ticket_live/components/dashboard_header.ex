defmodule TicketSplitterWeb.TicketLive.Components.DashboardHeader do
  @moduledoc """
  Top dashboard header with merchant info, participant counter, and action buttons.
  """
  use Phoenix.Component
  use TicketSplitterWeb, :html

  attr :ticket, :map, required: true
  attr :participant_name, :string, default: nil
  attr :participant_color, :string, default: nil
  attr :my_total, :any, default: nil
  attr :my_multiplier, :integer, default: 1
  attr :acting_as_participant, :string, default: nil
  attr :acting_as_color, :string, default: nil
  attr :acting_as_total, :any, default: nil
  attr :min_participants, :integer, required: true

  def dashboard_header(assigns) do
    ~H"""
    <!-- Top Dashboard Header -->
    <div class="bg-base-100 rounded-lg p-3 shadow-lg mb-4">
      <!-- Header: Title and Date -->
      <%= if @ticket.merchant_name || @ticket.date do %>
        <div class="text-center mb-3">
          <%= if @ticket.merchant_name do %>
            <div class="flex items-center justify-center">
              <div class="relative inline-flex items-center">
                <%= if @ticket.image_url do %>
                  <button
                    phx-click="open_image_modal"
                    class="absolute -left-4 -top-0.5 !w-5 !h-5 !min-w-0 !min-h-0 aspect-square rounded-full bg-primary/40 backdrop-blur-xl hover:bg-primary/60 flex items-center justify-center transition-all duration-200 active:scale-95 border border-primary/50 shadow-sm z-10"
                    title={gettext("View ticket image")}
                  >
                    <.icon name="hero-photo" class="!w-3 !h-3 text-primary" />
                  </button>
                <% end %>
                <h1 class="text-xl font-bold text-base-content tracking-tight">
                  {@ticket.merchant_name}
                </h1>
              </div>
            </div>
          <% end %>
          <%= if @ticket.date do %>
            <div class="flex items-center justify-center gap-1 text-base-content/40 mt-1">
              <.icon name="hero-calendar-days" class="w-3 h-3" />
              <time class="text-xs">
                {Calendar.strftime(@ticket.date, "%d %b %Y")}
              </time>
            </div>
          <% end %>
        </div>
      <% end %>

      <!-- Compact Actions Bar -->
      <div class="relative flex items-center justify-between">
        <!-- Mi Parte (simplified) -->
        <div class={[
          "relative flex items-end gap-1.5 bg-base-200 rounded-md px-2 py-2 border min-w-0 transition-all duration-300",
          @acting_as_participant && "border-warning bg-warning/5",
          !@acting_as_participant && "border-base-300"
        ]}>
          <div
            class="w-2 h-2 rounded-full flex-shrink-0 mb-1"
            style={"background-color: #{if @acting_as_participant, do: @acting_as_color, else: (if @participant_name, do: @participant_color, else: "#cbd5e1")}"}
          >
          </div>
          <div class="flex-1 min-w-0">
            <%= if @acting_as_participant do %>
              <div class="text-[10px] text-base-content/90 font-bold truncate leading-none mb-0.5 uppercase tracking-wide">
                {@acting_as_participant}
              </div>
              <div class="text-sm font-bold text-warning leading-none truncate">
                €{format_decimal(@acting_as_total)}
              </div>
            <% else %>
              <div class="text-[8px] text-base-content/50 leading-tight truncate">
                {gettext("My share")}
              </div>
              <div class="text-sm font-bold text-base-content flex items-center gap-0.5 leading-tight">
                <span class="truncate">
                  €{format_decimal(if @participant_name, do: @my_total, else: Decimal.new(0))}
                </span>
                <%= if @my_multiplier > 1 do %>
                  <span class="text-[9px] font-normal text-primary flex-shrink-0">
                    (×{@my_multiplier})
                  </span>
                <% end %>
              </div>
            <% end %>
          </div>

          <%= if @acting_as_participant do %>
            <button
              phx-click="clear_acting_as"
              class="absolute -top-[14px] -left-[4px] w-6 h-6 flex items-center justify-center text-warning/40 hover:text-white hover:bg-warning rounded-br-lg transition-all z-20"
              title={gettext("Return to my account")}
            >
              <.icon name="hero-x-mark" class="w-6 h-6 stroke-[4]" />
            </button>
          <% end %>
        </div>

        <!-- Participants Counter (perfectly centered) -->
        <div class="absolute left-1/2 -translate-x-1/2 flex items-center gap-1 bg-base-200 rounded-md px-1.5 py-1 border border-base-300">
          <button
            phx-click="decrement_participants"
            class="aspect-square w-1.5 bg-secondary/20 hover:bg-secondary/35 text-secondary rounded flex items-center justify-center transition-all duration-200 active:scale-95 disabled:opacity-40 disabled:cursor-not-allowed"
            disabled={@ticket.total_participants <= @min_participants}
          >
            <span class="text-xs font-extrabold leading-none">−</span>
          </button>
          <div class="flex flex-col items-center min-w-[18px]">
            <span class="text-base font-bold text-base-content leading-none">
              {@ticket.total_participants}
            </span>
            <span class="text-[7px] text-base-content/40 leading-none">
              {gettext("people")}
            </span>
          </div>
          <button
            phx-click="increment_participants"
            class="aspect-square w-1.5 bg-primary/20 hover:bg-primary/35 text-primary rounded flex items-center justify-center transition-all duration-200 active:scale-95"
          >
            <span class="text-xs font-extrabold leading-none">+</span>
          </button>
        </div>

        <!-- Action Buttons -->
        <div class="flex gap-1">
          <button
            phx-click="open_share_modal"
            class="aspect-square w-8 bg-primary/25 hover:bg-primary/40 text-primary rounded-md flex items-center justify-center transition-all duration-200 active:scale-95 shadow-sm border border-primary/30"
            title={gettext("Share")}
          >
            <.icon name="hero-share" class="w-3.5 h-3.5 stroke-2" />
          </button>
          <button
            phx-click="show_summary"
            class="aspect-square w-8 bg-primary/25 hover:bg-primary/40 text-primary rounded-md flex items-center justify-center transition-all duration-200 active:scale-95 shadow-sm border border-primary/30"
            title={gettext("Summary")}
          >
            <.icon name="hero-presentation-chart-bar" class="w-3.5 h-3.5 stroke-2" />
          </button>
        </div>
      </div>
    </div>
    """
  end

  defp format_decimal(decimal) do
    decimal
    |> Decimal.round(2)
    |> Decimal.to_string()
  end
end
