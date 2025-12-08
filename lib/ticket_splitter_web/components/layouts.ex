defmodule TicketSplitterWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use TicketSplitterWeb, :html

  alias TicketSplitterWeb.Components.SEOMeta

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

  attr :locale, :string, default: "en", doc: "current locale"
  attr :current_path, :string, default: "/", doc: "current request path"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="flex flex-col min-h-screen-dynamic bg-base-300">
      <header class="bg-base-300 border-b border-base-content/20 flex-none">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex items-center justify-between h-18 sm:h-22">
            <a href={"/#{@locale}/"} class="flex items-center gap-2.5 sm:gap-3">
              <img
                src={~p"/images/logo-color.svg"}
                alt=""
                class="h-7 sm:h-9 w-auto"
                loading="eager"
                width="28"
                height="28"
              />
              <span class="text-xl sm:text-2xl font-bold text-base-content">Ticket Splitter</span>
            </a>
            <div class="flex items-center gap-2">
              <.language_selector locale={@locale} current_path={@current_path} />
              <.theme_toggle />
            </div>
          </div>
        </div>
      </header>

      <main class="flex-1 flex flex-col bg-base-100 relative">
        {render_slot(@inner_block)}
      </main>

      <footer class="flex-none bg-base-300 border-t border-base-content/20 py-2">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <p class="text-center text-xs text-base-content/60">
            © kukapu - beta versión {app_version()}
          </p>
        </div>
      </footer>
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

  @doc """
  Language selector component for switching between supported locales.
  Displays as a dropdown menu using native HTML details/summary.
  """
  attr :locale, :string, required: true, doc: "current locale"
  attr :current_path, :string, required: true, doc: "current request path"

  @supported_locales [
    %{code: "en", name: "English", flag: "🇬🇧"},
    %{code: "es", name: "Español", flag: "🇪🇸"}
  ]

  def language_selector(assigns) do
    assigns = assign(assigns, :locales, @supported_locales)

    ~H"""
    <details class="relative group" id="language-dropdown">
      <summary class="flex items-center gap-1.5 px-2.5 py-1.5 bg-base-200 hover:bg-base-300 border border-base-300 rounded-lg transition-colors text-sm font-medium text-base-content cursor-pointer list-none select-none">
        <span class="text-base">{current_flag(@locale)}</span>
        <span class="hidden sm:inline">{String.upcase(@locale)}</span>
        <.icon
          name="hero-chevron-down"
          class="w-3.5 h-3.5 transition-transform group-open:rotate-180"
        />
      </summary>

      <div class="absolute right-0 mt-2 w-40 bg-base-100 border border-base-300 rounded-lg shadow-xl z-50 overflow-hidden">
        <%= for lang <- @locales do %>
          <%= if lang.code == @locale do %>
            <div class="flex items-center gap-2.5 px-3 py-2.5 bg-primary/10 text-base-content cursor-default">
              <span class="text-base">{lang.flag}</span>
              <span class="text-sm font-medium">{lang.name}</span>
              <.icon name="hero-check" class="w-4 h-4 ml-auto text-primary" />
            </div>
          <% else %>
            <a
              href={locale_path(@current_path, lang.code)}
              class="flex items-center gap-2.5 px-3 py-2.5 hover:bg-base-200 text-base-content transition-colors"
            >
              <span class="text-base">{lang.flag}</span>
              <span class="text-sm font-medium">{lang.name}</span>
            </a>
          <% end %>
        <% end %>
      </div>
    </details>
    """
  end

  defp current_flag("en"), do: "🇬🇧"
  defp current_flag("es"), do: "🇪🇸"
  defp current_flag(_), do: "🌐"

  @doc """
  Calculates the path for switching to a different locale.
  Replaces the locale segment in the current path while preserving the rest.
  """
  def locale_path(current_path, new_locale) do
    # Split path into segments, preserving empty first segment
    segments = String.split(current_path, "/")

    case segments do
      # Path like "/en/tickets/123" -> ["", "en", "tickets", "123"]
      ["", current_locale | rest] when current_locale in ["en", "es"] ->
        "/" <> new_locale <> "/" <> Enum.join(rest, "/")

      # Path like "/en/" -> ["", "en", ""]
      ["", current_locale, ""] when current_locale in ["en", "es"] ->
        "/" <> new_locale <> "/"

      # Path like "/en" -> ["", "en"]
      ["", current_locale] when current_locale in ["en", "es"] ->
        "/" <> new_locale <> "/"

      # Fallback
      _ ->
        "/" <> new_locale <> "/"
    end
  end

  defp app_version do
    Application.spec(:ticket_splitter, :vsn)
    |> case do
      vsn when is_list(vsn) -> List.to_string(vsn)
      _ -> "dev"
    end
  end
end
