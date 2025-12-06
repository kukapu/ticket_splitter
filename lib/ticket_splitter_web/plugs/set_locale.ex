defmodule TicketSplitterWeb.Plugs.SetLocale do
  @moduledoc """
  Plug that extracts the locale from URL params, validates it, sets Gettext locale,
  and manages the locale cookie for persistence.
  """
  import Plug.Conn

  @supported_locales ["en", "es"]
  @default_locale "en"
  @cookie_name "locale"
  # 1 year
  @cookie_max_age 60 * 60 * 24 * 365

  def init(opts), do: opts

  def call(conn, _opts) do
    locale = conn.params["locale"]

    if locale in @supported_locales do
      Gettext.put_locale(TicketSplitterWeb.Gettext, locale)

      conn
      |> put_session(:locale, locale)
      |> put_resp_cookie(@cookie_name, locale, max_age: @cookie_max_age)
    else
      # Invalid locale, redirect to default
      conn
      |> Phoenix.Controller.redirect(to: "/#{@default_locale}/")
      |> halt()
    end
  end

  @doc """
  Returns the list of supported locales.
  """
  def supported_locales, do: @supported_locales

  @doc """
  Returns the default locale.
  """
  def default_locale, do: @default_locale
end
