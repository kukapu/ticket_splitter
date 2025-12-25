defmodule TicketSplitterWeb.TicketLive.Components.ProductActions do
  @moduledoc """
  Action buttons for a product card (add, make common, remove).
  """
  use Phoenix.Component
  use TicketSplitterWeb, :html

  attr :product, :map, required: true

  def product_actions(assigns) do
    ~H"""
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
    """
  end
end
