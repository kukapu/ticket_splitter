defmodule TicketSplitterWeb.SEO do
  @moduledoc """
  Helper functions for SEO-related functionality including URL generation
  and meta tag helpers.
  """

  use TicketSplitterWeb, :verified_routes

  @site_name "Ticket Splitter"
  @default_description "Divide y gestiona tus tickets de forma fácil y rápida. Comparte gastos con amigos y familiares de manera intuitiva."

  @doc """
  Returns the base URL of the site from the endpoint configuration.
  """
  def site_url do
    endpoint = TicketSplitterWeb.Endpoint
    config = endpoint.config(:url)

    scheme = Keyword.get(config, :scheme, "http")
    host = Keyword.get(config, :host, "localhost")
    port = Keyword.get(config, :port, 4000)

    # Only include port if it's not the default port for the scheme
    port_part =
      case {scheme, port} do
        {"https", 443} -> ""
        {"http", 80} -> ""
        _ -> ":#{port}"
      end

    "#{scheme}://#{host}#{port_part}"
  end

  @doc """
  Converts a relative path to an absolute URL.
  """
  def absolute_url(path) when is_binary(path) do
    base_url = site_url()
    # Remove leading slash if present to avoid double slashes
    clean_path = String.trim_leading(path, "/")
    "#{base_url}/#{clean_path}"
  end

  @doc """
  Returns the absolute URL for the Open Graph image.
  Falls back to logo-color.svg if og-image.png doesn't exist.
  """
  def og_image_url do
    # Try og-image.png first, fallback to logo-color.svg
    absolute_url("/images/og-image.png")
  end

  @doc """
  Returns the site name.
  """
  def site_name, do: @site_name

  @doc """
  Returns the default description.
  """
  def default_description, do: @default_description

  @doc """
  Generates a page title with site name suffix.
  """
  def page_title(title) when is_binary(title) do
    if String.contains?(title, @site_name) do
      title
    else
      "#{title} - #{@site_name}"
    end
  end

  def page_title(nil), do: @site_name
  def page_title(_), do: @site_name
end
