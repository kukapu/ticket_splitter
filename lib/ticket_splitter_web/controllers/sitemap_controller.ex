defmodule TicketSplitterWeb.SitemapController do
  @moduledoc """
  Controller for generating sitemap.xml for SEO purposes.
  """
  use TicketSplitterWeb, :controller

  alias TicketSplitterWeb.SEO

  @doc """
  Generates and returns sitemap.xml with the main routes of the application.
  """
  def index(conn, _params) do
    base_url = SEO.site_url()

    # Rutas principales estáticas
    urls = [
      %{
        loc: base_url,
        changefreq: "daily",
        priority: "1.0",
        lastmod: format_date(Date.utc_today())
      }
    ]

    xml_content = generate_sitemap_xml(urls)

    conn
    |> put_resp_content_type("application/xml")
    |> put_resp_header("cache-control", "public, max-age=3600")
    |> send_resp(200, xml_content)
  end

  defp generate_sitemap_xml(urls) do
    url_entries =
      urls
      |> Enum.map(fn url ->
        """
          <url>
            <loc>#{escape_xml(url.loc)}</loc>
            <lastmod>#{url.lastmod}</lastmod>
            <changefreq>#{url.changefreq}</changefreq>
            <priority>#{url.priority}</priority>
          </url>
        """
      end)
      |> Enum.join("\n")

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
    #{url_entries}
    </urlset>
    """
  end

  defp escape_xml(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end

  defp format_date(date) do
    Calendar.strftime(date, "%Y-%m-%d")
  end
end
