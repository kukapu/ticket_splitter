defmodule TicketSplitterWeb.SitemapControllerTest do
  use TicketSplitterWeb.ConnCase, async: true

  describe "index/2" do
    test "returns sitemap XML" do
      conn = get(build_conn(), "/sitemap.xml")

      assert conn.status == 200
    end

    test "returns correct content type" do
      conn = get(build_conn(), "/sitemap.xml")

      content_type = get_resp_header(conn, "content-type")

      assert content_type |> List.first() |> String.contains?("xml")
    end

    test "contains required XML structure" do
      conn = get(build_conn(), "/sitemap.xml")
      body = response(conn, 200)

      assert body =~ "<?xml version"
      assert body =~ "<urlset"
      assert body =~ "<url>"
    end
  end
end
