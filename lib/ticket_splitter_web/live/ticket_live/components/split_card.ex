defmodule TicketSplitterWeb.TicketLive.Components.SplitCard do
  @moduledoc """
  Split card for 2-person shared groups with interactive divider.
  """
  use Phoenix.Component
  use TicketSplitterWeb, :html

  attr :group, :map, required: true
  attr :product, :map, required: true
  attr :active_participant_name, :string, required: true
  attr :has_me, :boolean, required: true

  def split_card(assigns) do
    unit_cost = Decimal.div(assigns.product.total_price, Decimal.new(assigns.product.units))
    total_group = Decimal.mult(unit_cost, assigns.group.units_assigned)

    assigns =
      assign(assigns, :unit_cost, unit_cost)
      |> assign(:total_group, total_group)

    ~H"""
    <%= if length(@group.participants) == 2 do %>
      <% # Reorder participants so current user is always first (left)
      reordered_participants =
        if @has_me do
          [current_user | others] =
            Enum.sort_by(
              @group.participants,
              fn p -> p.name == @active_participant_name end,
              :desc
            )

          [current_user | others]
        else
          @group.participants
        end %>
      <div
        class="colored-card split-card-row rounded-lg overflow-hidden border-2 new-card cursor-pointer"
        style={"border-color: #{hd(reordered_participants).color}"}
        phx-click="toggle_product"
        phx-value-product_id={@product.id}
        phx-value-action={if @has_me, do: "remove_unit", else: "join_group"}
        phx-value-group_id={@group.group_id}
        id={"split-card-#{@group.group_id}"}
      >
        <div class="flex h-full relative">
          <%= for {participant, index} <- Enum.with_index(reordered_participants) do %>
            <% participant_share =
              Decimal.mult(
                @total_group,
                Decimal.div(participant.percentage, Decimal.new("100"))
              ) %>
            <% participant_color = participant.color %>

            <div
              class="split-card-participant py-1 px-1.5 sm:py-1.5 sm:px-1.5 relative transition-all duration-200 flex justify-between items-center min-h-[28px] sm:min-h-[36px]"
              style={"background-color: #{participant_color}15; width: #{participant.percentage}%"}
              id={"participant-#{@group.group_id}-#{index}"}
            >
              <div class="flex items-center justify-between h-full w-full">
                <!-- Left side content (name, units) -->
                <div class="flex items-center gap-1.5 min-w-0 flex-1 pl-1">
                  <%= if participant.name == @active_participant_name do %>
                    <div class="w-4 h-4 bg-base-content/90 rounded-full flex items-center justify-center flex-shrink-0 z-10">
                      <.icon name="hero-user" class="w-2.5 h-2.5 text-base-100" />
                    </div>
                  <% end %>
                  <div class="min-w-0">
                    <p class="text-xs font-bold text-base-content truncate">
                      {participant.name}
                    </p>
                  </div>
                  <span class="text-[9px] text-base-content/50 flex-shrink-0">
                    {format_decimal(@group.units_assigned)}u
                  </span>
                </div>
                <!-- Right side content (price, percentage) -->
                <div class="text-right flex-shrink-0 pr-1 relative z-10">
                  <p class="text-xs font-bold text-base-content">
                    €{format_decimal(participant_share)}
                  </p>
                  <p class="text-[8px] text-base-content/40 percentage-display">
                    {format_decimal(participant.percentage)}%
                  </p>
                </div>
              </div>

              <!-- Overlay to prevent text overlap -->
              <%= if index == 0 do %>
                <div
                  class="absolute right-0 top-0 bottom-0 w-8 bg-gradient-to-l from-transparent to-transparent pointer-events-none"
                  style="z-index: 5;"
                >
                </div>
              <% else %>
                <div
                  class="absolute left-0 top-0 bottom-0 w-8 bg-gradient-to-r from-transparent to-transparent pointer-events-none"
                  style="z-index: 5;"
                >
                </div>
              <% end %>
            </div>
          <% end %>

          <!-- Interactive Divider Bar -->
          <%= if @has_me or Enum.any?(@group.participants, fn p -> p.name == @active_participant_name end) do %>
            <% # Get original alphabetical order (same as database)
            original_order = Enum.map(@group.participants, & &1.name) %>
            <div
              class="interactive-divider absolute top-0 h-full w-1 bg-base-content cursor-ew-resize z-20 hover:bg-warning transition-colors shadow-lg"
              style={"left: #{hd(reordered_participants).percentage}%; transform: translateX(-50%)"}
              id={"divider-#{@group.group_id}"}
              phx-hook="SplitDivider"
              data-group-id={@group.group_id}
              data-product-id={@product.id}
              data-total-price={Decimal.to_string(@total_group)}
              data-participant1-name={Enum.at(original_order, 0)}
              data-participant2-name={Enum.at(original_order, 1)}
            >
              <div class="absolute top-1/2 left-1/2 transform -translate-x-1/2 -translate-y-1/2 w-6 h-6 bg-base-100 rounded-full shadow-lg flex items-center justify-center hover:scale-110 transition-transform border border-base-content">
                <div class="w-1 h-4 bg-base-300 rounded"></div>
              </div>
              <div class="absolute bottom-1 left-1/2 transform -translate-x-1/2 bg-base-content/90 text-base-100 text-xs px-2 py-1 rounded whitespace-nowrap opacity-0 hover:opacity-100 transition-opacity">
                {gettext("Drag to adjust")}
              </div>
            </div>
          <% end %>
        </div>
      </div>
    <% end %>
    """
  end

  defp format_decimal(decimal) do
    decimal
    |> Decimal.round(2)
    |> Decimal.to_string()
  end
end
