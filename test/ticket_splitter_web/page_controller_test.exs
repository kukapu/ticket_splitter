defmodule TicketSplitterWeb.PageControllerTest do
  use TicketSplitterWeb.ConnCase, async: true

  describe "index/2" do
    test "redirects to locale path when no locale" do
      conn = get(build_conn(), "/")

      assert redirected_to(conn, 302) =~ "/en/"
    end

    test "redirects to correct locale based on accept-language" do
      conn =
        build_conn()
        |> put_req_header("accept-language", "es")
        |> get("/")

      assert redirected_to(conn, 302) =~ "/es/"
    end
  end

  describe "redirect_ticket/2" do
    test "redirects to ticket with locale prefix" do
      conn = get(build_conn(), "/tickets/test-123")

      assert redirected_to(conn, 302) =~ "/tickets/test-123"
    end
  end
end
