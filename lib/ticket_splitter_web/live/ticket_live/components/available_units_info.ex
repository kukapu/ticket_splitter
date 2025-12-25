defmodule TicketSplitterWeb.TicketLive.Components.AvailableUnitsInfo do
  @moduledoc """
  Display available units info for a product (available, common, assigned).
  """
  use Phoenix.Component
  use TicketSplitterWeb, :html

  alias TicketSplitter.Tickets

  attr :product, :map, required: true

  def available_units_info(assigns) do
    ~H"""
    <!-- Available Units Info -->
    <div class="mt-0.5 flex gap-2 text-xs flex-wrap">
      <% available = Tickets.get_available_units(@product.id) %>
      <% common_units = @product.common_units || Decimal.new("0") %>
      <% assigned = Tickets.get_total_assigned_units(@product.id) %>

      <span class="text-primary font-bold">
        {format_decimal(available)} {gettext("available")}
      </span>

      <%= if Decimal.compare(common_units, Decimal.new("0")) == :gt do %>
        <span class="text-accent font-bold">
          · {format_decimal(common_units)} {gettext("common")}
        </span>
      <% end %>

      <%= if Decimal.compare(assigned, Decimal.new("0")) == :gt do %>
        <span class="text-success font-bold">
          · {format_decimal(assigned)} {gettext("assigned")}
        </span>
      <% end %>
    </div>
    """
  end

  defp format_decimal(decimal) do
    decimal
    |> Decimal.round(2)
    |> Decimal.to_string()
  end
end
