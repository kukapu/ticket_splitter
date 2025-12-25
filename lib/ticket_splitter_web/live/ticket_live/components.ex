defmodule TicketSplitterWeb.TicketLive.Components do
  @moduledoc """
  Module that imports all ticket-related components for easy use in templates.
  """

  defmacro __using__(_) do
    quote do
      import TicketSplitterWeb.TicketLive.Components.DashboardHeader
      import TicketSplitterWeb.TicketLive.Components.InstructionsSection
      import TicketSplitterWeb.TicketLive.Components.ProductHeader
      import TicketSplitterWeb.TicketLive.Components.AvailableUnitsInfo
      import TicketSplitterWeb.TicketLive.Components.ProductActions
      import TicketSplitterWeb.TicketLive.Components.CommonUnitsCard
      import TicketSplitterWeb.TicketLive.Components.SplitCard
      import TicketSplitterWeb.TicketLive.Components.IndividualCard
      import TicketSplitterWeb.TicketLive.Components.CommonProductCard
    end
  end
end
