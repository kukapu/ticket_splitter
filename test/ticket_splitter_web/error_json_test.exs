defmodule TicketSplitterWeb.ErrorJSONTest do
  use TicketSplitterWeb.ConnCase, async: true

  alias TicketSplitterWeb.ErrorJSON

  describe "render/2" do
    test "renders 404" do
      result = ErrorJSON.render("404.json", %{})

      assert is_map(result)
      assert result.errors.detail == "Not Found"
    end

    test "renders 500" do
      result = ErrorJSON.render("500.json", %{})

      assert is_map(result)
      assert result.errors.detail == "Internal Server Error"
    end
  end
end
