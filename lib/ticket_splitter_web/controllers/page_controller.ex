defmodule TicketSplitterWeb.PageController do
  @moduledoc """
  Traffic Cop controller - handles the root path "/" and redirects
  to the appropriate locale based on cookie, Accept-Language header, or default.
  """
  use TicketSplitterWeb, :controller

  alias TicketSplitterWeb.Plugs.SetLocale

  @cookie_name "locale"

  def index(conn, _params) do
    locale =
      get_cookie_locale(conn) ||
        get_accept_language_locale(conn) ||
        SetLocale.default_locale()

    redirect(conn, to: "/#{locale}/")
  end

  @doc """
  Redirects legacy /tickets/:id URLs to the localized version.
  """
  def redirect_ticket(conn, %{"id" => id}) do
    locale =
      get_cookie_locale(conn) ||
        get_accept_language_locale(conn) ||
        SetLocale.default_locale()

    redirect(conn, to: "/#{locale}/tickets/#{id}")
  end

  defp get_cookie_locale(conn) do
    locale = conn.cookies[@cookie_name]
    if locale && locale in ["en", "es"], do: locale, else: nil
  end

  defp get_accept_language_locale(conn) do
    case get_req_header(conn, "accept-language") do
      [lang_header | _] ->
        parse_accept_language(lang_header)

      _ ->
        nil
    end
  end

  defp parse_accept_language(header) do
    header
    |> String.split(",")
    |> Enum.map(&parse_language_tag/1)
    |> Enum.sort_by(fn {_lang, quality} -> quality end, :desc)
    |> Enum.find_value(fn {lang, _quality} ->
      normalized = normalize_language(lang)
      if normalized in SetLocale.supported_locales(), do: normalized, else: nil
    end)
  end

  defp parse_language_tag(tag) do
    case String.split(String.trim(tag), ";") do
      [lang] ->
        {lang, 1.0}

      [lang, quality_str] ->
        quality =
          case Regex.run(~r/q=(\d+\.?\d*)/, quality_str) do
            [_, q] -> String.to_float(ensure_decimal(q))
            _ -> 1.0
          end

        {lang, quality}

      _ ->
        {"", 0.0}
    end
  end

  defp ensure_decimal(str) do
    if String.contains?(str, "."), do: str, else: str <> ".0"
  end

  defp normalize_language(lang) do
    lang
    |> String.trim()
    |> String.downcase()
    |> String.split("-")
    |> hd()
  end
end
