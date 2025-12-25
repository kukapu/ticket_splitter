defmodule TicketSplitterWeb.TicketLive.Components.ProductHeader do
  @moduledoc """
  Product header with name, price breakdown, and available units display.
  """
  use Phoenix.Component
  use TicketSplitterWeb, :html

  alias TicketSplitter.Tickets

  attr :product, :map, required: true
  attr :available_units, :any, required: true

  def product_header(assigns) do
    available_decimal = Decimal.to_float(assigns.available_units)

    assigns =
      assign(assigns, :available_decimal, available_decimal)

    ~H"""
    <!-- Product Header -->
    <div
      class={[
        "product-header rounded-lg p-2",
        @available_decimal > 0 &&
          "bg-primary/5 border border-dashed border-primary/20",
        @available_decimal <= 0 && "bg-base-200"
      ]}
      id={"available-units-#{@product.id}"}
    >
      <div class="flex justify-between items-center gap-2">
        <div class="flex-1 min-w-0">
          <h3 class="text-sm sm:text-base font-semibold text-base-content line-clamp-2">
            {@product.name}
          </h3>
          <p class="text-xs text-base-content/50 truncate">
            {@product.units}u × €{format_decimal(@product.unit_price)} = €{format_decimal(
              @product.total_price
            )}
          </p>

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
        </div>

        <!-- Action Buttons -->
        <div class="flex flex-row gap-1 flex-shrink-0">
          <button
            phx-click="toggle_product"
            phx-value-product_id={@product.id}
            phx-value-action="remove_unit"
            class="aspect-square w-8 bg-secondary/25 hover:bg-secondary/40 text-secondary rounded-lg flex items-center justify-center transition-all duration-200 active:scale-95 shadow-sm border border-secondary/30"
            title={gettext("Remove 1 unit from my account")}
          >
            <span class="text-sm font-extrabold">−</span>
          </button>

          <button
            phx-click="make_common"
            phx-value-product_id={@product.id}
            class="aspect-square w-8 bg-accent/25 hover:bg-accent/40 text-accent rounded-lg flex items-center justify-center transition-all duration-200 active:scale-95 shadow-sm border border-accent/30"
            title={gettext("Make common for everyone")}
          >
            <.icon name="hero-users" class="w-4 h-4 stroke-2" />
          </button>

          <button
            phx-click="toggle_product"
            phx-value-product_id={@product.id}
            phx-value-action="add_unit"
            class="aspect-square w-8 bg-primary/25 hover:bg-primary/40 text-primary rounded-lg flex items-center justify-center transition-all duration-200 active:scale-95 shadow-sm border border-primary/30"
            title={gettext("Add 1 unit to my account")}
          >
            <span class="text-sm font-extrabold">+</span>
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
