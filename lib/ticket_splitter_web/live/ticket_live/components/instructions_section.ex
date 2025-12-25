defmodule TicketSplitterWeb.TicketLive.Components.InstructionsSection do
  @moduledoc """
  Collapsible usage instructions section.
  """
  use Phoenix.Component
  use TicketSplitterWeb, :html

  attr :show_instructions, :boolean, required: true

  def instructions_section(assigns) do
    ~H"""
    <!-- Collapsible Instructions -->
    <div class="mt-4">
      <button
        phx-click="toggle_instructions"
        class="w-full text-left bg-base-200 border border-base-300 rounded-lg p-3 hover:bg-base-300 transition-colors"
      >
        <div class="flex justify-between items-center">
          <span class="text-sm font-medium text-base-content/70">
            ℹ️ {gettext("Usage instructions")}
          </span>
          <.icon
            name="hero-chevron-down"
            class={"w-4 h-4 text-base-content/50 transition-transform #{if @show_instructions, do: "rotate-180"}"}
          />
        </div>
      </button>
      <%= if @show_instructions do %>
        <div class="mt-2 bg-base-200 border border-base-300 rounded-lg p-3 text-xs text-base-content/70">
          <ul class="space-y-1">
            <li>
              •
              <strong>{gettext("+ Button")}</strong> {gettext(
                "on available products to add 1 unit to yourself"
              )}
            </li>
            <li>
              •
              <strong>{gettext("- Button")}</strong> {gettext(
                "on available products to remove 1 unit from yourself"
              )}
            </li>
            <li>
              •
              <strong>{gettext("Common button")}</strong> {gettext(
                "on available products to make common for everyone"
              )}
            </li>
            <li>• {gettext("Click on someone else's group to share (50-50)")}</li>
          </ul>
        </div>
      <% end %>
    </div>
    """
  end
end
