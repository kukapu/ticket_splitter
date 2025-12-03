defmodule TicketSplitterWeb.Components.SEOMeta do
  @moduledoc """
  Component for generating SEO meta tags including Open Graph and Twitter Cards.
  """
  use Phoenix.Component

  alias TicketSplitterWeb.SEO

  @doc """
  Renders SEO meta tags including Open Graph and Twitter Cards.

  ## Assigns

  * `:page_title` - The page title (optional, defaults to site name)
  * `:page_description` - The page description (optional, defaults to default description)
  * `:page_image` - The OG/Twitter image URL (optional, defaults to og-image.png)
  * `:page_url` - The canonical URL (optional, defaults to current request URL)
  * `:page_type` - The OG type (optional, defaults to "website")
  """
  attr :page_title, :string, default: nil
  attr :page_description, :string, default: nil
  attr :page_image, :string, default: nil
  attr :page_url, :string, default: nil
  attr :page_type, :string, default: "website"

  def seo_meta(assigns) do
    title = assigns.page_title || SEO.site_name()
    description = assigns.page_description || SEO.default_description()
    image = assigns.page_image || SEO.og_image_url()
    url = assigns.page_url || SEO.site_url()
    type = assigns.page_type

    ~H"""
    <%!-- Basic SEO Meta Tags --%>
    <meta name="description" content={description} />
    <meta
      name="keywords"
      content="ticket splitter, dividir gastos, compartir tickets, gestión de gastos, dividir cuenta restaurante"
    />
    <meta name="author" content="Ticket Splitter" />
    <meta name="robots" content="index, follow" />

    <%!-- Canonical URL --%>
    <link rel="canonical" href={url} />

    <%!-- Open Graph / Facebook --%>
    <meta property="og:type" content={type} />
    <meta property="og:title" content={title} />
    <meta property="og:description" content={description} />
    <meta property="og:image" content={image} />
    <meta property="og:image:width" content="1200" />
    <meta property="og:image:height" content="630" />
    <meta property="og:url" content={url} />
    <meta property="og:site_name" content={SEO.site_name()} />
    <meta property="og:locale" content="es_ES" />

    <%!-- Twitter Card --%>
    <meta name="twitter:card" content="summary_large_image" />
    <meta name="twitter:title" content={title} />
    <meta name="twitter:description" content={description} />
    <meta name="twitter:image" content={image} />

    <%!-- Modern Meta Tags --%>
    <meta name="theme-color" content="#3b82f6" />
    <meta name="apple-mobile-web-app-capable" content="yes" />
    <meta name="apple-mobile-web-app-status-bar-style" content="default" />
    <meta name="apple-mobile-web-app-title" content={SEO.site_name()} />
    <meta name="format-detection" content="telephone=no" />
    <meta name="referrer" content="strict-origin-when-cross-origin" />
    """
  end

  @doc """
  Renders structured data JSON-LD for WebSite schema.
  """
  attr :page_url, :string, default: nil

  def structured_data(assigns) do
    url = assigns.page_url || SEO.site_url()

    json_ld = %{
      "@context" => "https://schema.org",
      "@type" => "WebSite",
      "name" => SEO.site_name(),
      "url" => url,
      "description" => SEO.default_description()
    }

    json_string = Phoenix.json_library().encode!(json_ld)

    ~H"""
    <script type="application/ld+json" phx-no-format>{raw(json_string)}</script>
    """
  end
end
