defmodule TicketSplitterWeb.RouterTest do
  use TicketSplitterWeb.ConnCase, async: true

  describe "routes" do
    test "redirects to localized home" do
      conn = get(build_conn(), "/")

      assert conn.status == 302
      assert redirected_to(conn) == "/en/"
    end

    test "handles legacy ticket redirect" do
      conn = get(build_conn(), "/tickets/test-123")

      assert conn.status == 302
      assert redirected_to(conn) == "/en/tickets/test-123"
    end
  end
end
