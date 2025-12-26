defmodule TicketSplitterWeb.ErrorHTMLTest do
  use TicketSplitterWeb.ConnCase, async: true

  alias TicketSplitterWeb.ErrorHTML

  describe "render/2" do
    test "renders 404 error" do
      html = ErrorHTML.render("404", %{})

      assert is_binary(html)
    end

    test "renders 500 error" do
      html = ErrorHTML.render("500", %{})

      assert is_binary(html)
    end
  end
end
