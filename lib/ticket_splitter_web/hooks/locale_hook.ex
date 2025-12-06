defmodule TicketSplitterWeb.Hooks.LocaleHook do
  @moduledoc """
  LiveView on_mount hook that sets the Gettext locale for the LiveView process
  and assigns the locale to the socket for template access.
  """
  import Phoenix.Component
  import Phoenix.LiveView

  alias TicketSplitterWeb.Plugs.SetLocale

  def on_mount(:set_locale, params, session, socket) do
    # Get locale from URL params (primary) or session (fallback)
    locale =
      params["locale"] ||
        session["locale"] ||
        SetLocale.default_locale()

    # Validate and set locale
    locale =
      if locale in SetLocale.supported_locales(), do: locale, else: SetLocale.default_locale()

    Gettext.put_locale(TicketSplitterWeb.Gettext, locale)

    # Build current path from URI
    current_path = get_current_path(socket, locale, params)

    socket =
      socket
      |> assign(:locale, locale)
      |> assign(:current_path, current_path)
      |> attach_hook(:update_path, :handle_params, fn _params, uri, socket ->
        # Update current_path on navigation
        path = URI.parse(uri).path || "/"
        {:cont, assign(socket, :current_path, path)}
      end)

    {:cont, socket}
  end

  defp get_current_path(socket, locale, params) do
    # Try to get from socket's private connect_info first
    case socket.private do
      %{connect_info: %{request_path: path}} when is_binary(path) and path != "" ->
        path

      _ ->
        # Build from params - this is the route pattern
        build_path_from_params(locale, params)
    end
  end

  defp build_path_from_params(locale, params) do
    case params do
      %{"id" => id} ->
        # We're on a ticket page
        "/#{locale}/tickets/#{id}"

      _ ->
        # We're on the home page
        "/#{locale}/"
    end
  end
end
