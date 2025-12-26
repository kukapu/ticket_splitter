defmodule TicketSplitterWeb.TicketLive.Components.CommonUnitsCard do
  @moduledoc """
  Card displaying common units with per-person cost calculation.
  """
  use Phoenix.Component
  use TicketSplitterWeb, :html

  attr :product, :map, required: true
  attr :common_units, :any, required: true
  attr :total_participants, :integer, required: true

  def common_units_card(assigns) do
    ~H"""
    <!-- Common Units Card -->
    <% common_units = @common_units %>
    <%= if Decimal.compare(common_units, Decimal.new("0")) == :gt do %>
      <div class="colored-card rounded-lg border-2 border-accent bg-accent/10 mb-1.5 mt-1.5 new-card">
        <div class="p-1.5 pl-3">
          <div class="flex items-center justify-between gap-2">
            <div class="text-left min-w-0 flex-1">
              <p class="text-xs font-bold text-base-content flex items-center gap-1">
                <.icon name="hero-users" class="w-3.5 h-3.5" />
                <span>
                  {gettext("COMMON")} ({@total_participants} {gettext("pers.")})
                </span>
              </p>
              <p class="text-[9px] text-base-content/60">
                {format_decimal(common_units)}u
              </p>
            </div>

            <div class="text-right min-w-0">
              <% unit_cost =
                Decimal.div(@product.total_price, Decimal.new(@product.units)) %>
              <% total_common_cost = Decimal.mult(unit_cost, common_units) %>
              <% safe_participants = max(@total_participants, 1) %>
              <% per_person_cost =
                Decimal.div(total_common_cost, Decimal.new(safe_participants)) %>

              <p class="text-xs font-bold text-base-content truncate">
                €{format_decimal(total_common_cost)}
              </p>
              <p class="text-[9px] text-base-content/50">
                €{format_decimal(per_person_cost)} / pers.
              </p>
            </div>

            <div class="flex flex-row gap-0.5 flex-shrink-0">
              <button
                type="button"
                phx-click="remove_common_unit"
                phx-value-product_id={@product.id}
                class="aspect-square w-6 bg-secondary/25 hover:bg-secondary/40 text-secondary rounded-lg flex items-center justify-center transition-all duration-200 active:scale-95 shadow-sm border border-secondary/30"
                title={gettext("Remove 1 unit from common")}
              >
                <span class="text-sm font-extrabold">−</span>
              </button>
              <button
                type="button"
                phx-click="add_common_unit"
                phx-value-product_id={@product.id}
                class="aspect-square w-6 bg-primary/25 hover:bg-primary/40 text-primary rounded-lg flex items-center justify-center transition-all duration-200 active:scale-95 shadow-sm border border-primary/30"
                title={gettext("Add 1 more unit to common")}
              >
                <span class="text-sm font-extrabold">+</span>
              </button>
            </div>
          </div>
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
