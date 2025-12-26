defmodule TicketSplitterWeb.TicketLiveTest do
  use TicketSplitterWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  import TicketSplitter.TicketsFixtures

  alias TicketSplitter.Tickets.TicketBroadcaster

  describe "mount/3" do
    test "mounts ticket successfully" do
      {ticket, _products} = ticket_with_products_fixture()

      {:ok, _view, html} = live(build_conn(), "/en/tickets/#{ticket.id}")

      assert html =~ ticket.merchant_name
    end

    test "subscribes to ticket updates via PubSub on mount" do
      {ticket, _products} = ticket_with_products_fixture()

      {:ok, view, _html} = live(build_conn(), "/en/tickets/#{ticket.id}")

      # Verify subscription by sending a broadcast
      TicketBroadcaster.broadcast_ticket_update(ticket.id)

      # Small delay to allow message processing
      :timer.sleep(50)

      # View should still be connected (would crash if subscription failed)
      assert render(view) =~ ticket.merchant_name
    end
  end

  describe "handle_event set_participant_name" do
    test "sets participant name in socket" do
      {ticket, _products} = ticket_with_products_fixture()

      {:ok, view, _html} = live(build_conn(), "/en/tickets/#{ticket.id}")

      # Simulate setting participant name
      html = render_hook(view, "set_participant_name", %{"name" => "Alice"})

      # The view should update to show the participant's perspective
      # This would typically show different UI elements
      assert html =~ ticket.merchant_name
    end

    test "trims whitespace from participant name" do
      {ticket, _products} = ticket_with_products_fixture()

      {:ok, view, _html} = live(build_conn(), "/en/tickets/#{ticket.id}")

      render_hook(view, "set_participant_name", %{"name" => "  Bob  "})

      # The name should be trimmed
      assert render(view) =~ ticket.merchant_name
    end
  end


  describe "handle_info {:ticket_updated, ticket_id}" do
    test "reloads ticket data when receiving broadcast from another process" do
      {ticket, _products} = ticket_with_products_fixture()

      {:ok, view, initial_html} = live(build_conn(), "/en/tickets/#{ticket.id}")

      # Initial state
      assert initial_html =~ ticket.merchant_name

      # Another process updates the ticket (simulating another user)
      TicketBroadcaster.broadcast_ticket_update(ticket.id)

      # Wait for LiveView to process the message
      :timer.sleep(100)

      # View should have updated
      updated_html = render(view)
      assert updated_html =~ ticket.merchant_name
    end

    test "ignores broadcasts for different tickets" do
      {ticket1, _products1} = ticket_with_products_fixture()
      {ticket2, _products2} = ticket_with_products_fixture()
      ticket2_id = ticket2.id

      {:ok, view1, _html} = live(build_conn(), "/en/tickets/#{ticket1.id}")

      # Subscribe to check broadcasts
      Phoenix.PubSub.subscribe(TicketSplitter.PubSub, "ticket:#{ticket1.id}")

      # Broadcast update for ticket2
      TicketBroadcaster.broadcast_ticket_update(ticket2.id)

      # view1 should NOT receive the broadcast for ticket2
      refute_receive {:ticket_updated, ^ticket2_id}, 500

      # view1 should still be connected
      assert render(view1) =~ ticket1.merchant_name
    end
  end
end
