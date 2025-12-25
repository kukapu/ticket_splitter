defmodule TicketSplitterWeb.TicketLive.Components.IndividualCard do
  @moduledoc """
  Individual or multi-person (3+) participant card.
  """
  use Phoenix.Component
  use TicketSplitterWeb, :html

  attr :group, :map, required: true
  attr :product, :map, required: true
  attr :active_participant_name, :string, required: true
  attr :has_me, :boolean, required: true
  attr :is_shared, :boolean, required: true

  def individual_card(assigns) do
    unit_cost = Decimal.div(assigns.product.total_price, Decimal.new(assigns.product.units))
    total_group = Decimal.mult(unit_cost, assigns.group.units_assigned)

    assigns = assign(assigns, :total_group, total_group)

    ~H"""
    <% # For single user or multi-user (more than 2), prioritize current user's color if present
    main_participant =
      if @has_me do
        Enum.find(@group.participants, fn p ->
          p.name == @active_participant_name
        end)
      else
        hd(@group.participants)
      end

    card_color = main_participant.color %>
    <div
      class={[
        "colored-card rounded-lg overflow-hidden border-2 new-card cursor-pointer relative",
        (@has_me && "colored-card-mine") || "colored-card-individual"
      ]}
      style={"background-color: #{card_color}15; border-color: #{card_color}"}
      phx-click="toggle_product"
      phx-value-product_id={@product.id}
      phx-value-action={if @has_me, do: "remove_unit", else: "join_group"}
      phx-value-group_id={@group.group_id}
    >
      <div
        class={[
          "absolute top-0 left-0 flex items-center justify-center",
          (@has_me && "w-5 h-full") || "w-2 h-full"
        ]}
        style={"background-color: #{card_color}"}
      >
        <%= if @has_me do %>
          <div class="w-full h-full flex items-center justify-center bg-white/20">
            <.icon name="hero-user" class="w-4 h-4 text-white drop-shadow-md" />
          </div>
        <% end %>
      </div>
      <div class={[
        "py-1 px-1.5 sm:py-1.5 sm:px-1.5",
        (@has_me && "pl-5 sm:pl-6") || "pl-3 sm:pl-3"
      ]}>
        <div class="flex items-center justify-between gap-2">
          <div class="flex items-center gap-2 min-w-0 flex-1">
            <div class="text-left min-w-0">
              <p class="text-xs font-bold text-base-content truncate">
                <%= if @is_shared && length(@group.participants) > 2 do %>
                  👥 {gettext("Shared")} ({length(@group.participants)})
                <% else %>
                  {main_participant.name}
                <% end %>
              </p>
              <p class="text-[9px] text-base-content/60">
                {format_decimal(@group.units_assigned)}u
              </p>
            </div>

            <!-- Participants indicators -->
            <div class="flex gap-0.5 flex-shrink-0">
              <%= for participant <- @group.participants do %>
                <div
                  class="participant-dot w-3.5 h-3.5 rounded-full border border-base-content/60"
                  style={"background-color: #{participant.color}"}
                  title={participant.name}
                >
                </div>
              <% end %>
            </div>
          </div>

          <div class="text-right flex-shrink-0">
            <p class="text-xs font-bold text-base-content">
              €{format_decimal(@total_group)}
            </p>
            <%= if @is_shared && length(@group.participants) > 1 do %>
              <p class="text-[9px] text-base-content/50">
                <%= if length(@group.participants) == 2 do %>
                  50-50
                <% else %>
                  {length(@group.participants)} {gettext("pers.")}
                <% end %>
              </p>
            <% end %>
          </div>
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
