defmodule TicketSplitterWeb.TicketLive.Components.CommonProductCard do
  @moduledoc """
  Legacy common product card (is_common = true).
  """
  use Phoenix.Component
  use TicketSplitterWeb, :html

  attr :product, :map, required: true
  attr :total_participants, :integer, required: true

  def common_product_card(assigns) do
    ~H"""
    <!-- Common Product -->
    <div
      class="bg-base-200 border-2 border-primary rounded-xl p-2.5 sm:p-3 transition-all duration-200 hover:border-primary"
      id={"product-#{@product.id}"}
      phx-hook="SwipeHandler"
      data-product-id={@product.id}
      data-is-common="true"
      title={gettext("Swipe to remove from common")}
    >
      <div class="flex justify-between items-center gap-2">
        <div class="min-w-0 flex-1">
          <h3 class="text-sm sm:text-base font-semibold text-base-content line-clamp-2">
            {@product.name}
          </h3>
          <p class="text-xs text-base-content/50 truncate">
            {@product.units}u × €{format_decimal(@product.unit_price)}
          </p>
        </div>
        <div class="flex items-center gap-2 flex-shrink-0">
          <div class="text-right">
            <span class="px-2 sm:px-3 py-1 bg-primary text-base-content text-xs sm:text-sm font-semibold rounded-full whitespace-nowrap">
              <.icon name="hero-users" class="w-3 sm:w-4 h-3 sm:h-4 inline mr-1" /> {gettext(
                "COMMON"
              )}
            </span>
            <p class="text-xs sm:text-sm font-bold text-base-content mt-1">
              €{format_decimal(@product.total_price)}
            </p>
            <p class="text-[10px] xs:text-xs text-base-content/50">
              ({@total_participants} {gettext("pers.")})
            </p>
          </div>
          <button
            phx-click="remove_from_common"
            phx-value-product_id={@product.id}
            class="aspect-square w-9 sm:w-10 bg-secondary hover:bg-secondary/80 text-secondary-content rounded-lg flex items-center justify-center transition-all duration-200 active:scale-95 shadow-sm"
            title={gettext("Remove from common")}
          >
            <span class="text-base sm:text-lg font-bold">−</span>
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
