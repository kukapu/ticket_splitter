defmodule TicketSplitterWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use TicketSplitterWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="flex flex-col min-h-screen-dynamic">
      <header class="bg-base-300 border-b border-base-content/20 flex-none">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex items-center justify-between h-18 sm:h-22">
            <a href="/" class="flex items-center gap-2.5 sm:gap-3">
              <img src={~p"/images/logo-color.svg"} alt="Ticket Splitter Logo" class="h-7 sm:h-9 w-auto" />
              <span class="text-xl sm:text-2xl font-bold text-base-content">Ticket Splitter</span>
            </a>
            <div>
              <.theme_toggle />
            </div>
          </div>
        </div>
      </header>

      <main class="flex-1 flex flex-col bg-base-100 relative">
        {render_slot(@inner_block)}
      </main>
    </div>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center gap-0.5 sm:gap-1 border sm:border-2 border-base-300 bg-base-300 rounded-full p-0.5 sm:p-1 h-8 sm:h-auto">
      <div class="absolute w-1/2 h-7 sm:h-full rounded-full border-1 border-base-200 bg-base-100 left-0 [[data-theme=dark]_&]:left-1/2 transition-[left] shadow-md top-0.5 sm:top-0" />

      <button
        class="flex p-1 sm:p-3 cursor-pointer w-1/2 h-7 sm:h-auto items-center justify-center hover:scale-110 transition-transform rounded-full z-10"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-5 sm:size-7 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-1 sm:p-3 cursor-pointer w-1/2 h-7 sm:h-auto items-center justify-center hover:scale-110 transition-transform rounded-full z-10"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-5 sm:size-7 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
