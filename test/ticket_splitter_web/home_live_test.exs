defmodule TicketSplitterWeb.HomeLiveTest do
  use TicketSplitterWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  describe "mount/3" do
    test "mounts successfully" do
      {:ok, _view, html} = live(build_conn(), "/en")

      assert html =~ "Upload"
    end
  end
end
