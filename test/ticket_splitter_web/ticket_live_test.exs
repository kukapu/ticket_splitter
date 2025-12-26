defmodule TicketSplitterWeb.TicketLiveTest do
  use TicketSplitterWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import TicketSplitter.TicketsFixtures

  describe "mount/3" do
    test "mounts ticket successfully" do
      {ticket, _products} = ticket_with_products_fixture()

      {:ok, _view, html} = live(build_conn(), "/en/tickets/#{ticket.id}")

      assert html =~ ticket.merchant_name
    end
  end
end
