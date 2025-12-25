defmodule TicketSplitter.Tickets.TicketBroadcasterTest do
  use TicketSplitter.DataCase

  alias TicketSplitter.Tickets.TicketBroadcaster

  describe "broadcast_ticket_update/1" do
    test "broadcasts ticket update event" do
      ticket_id = "test-ticket-123"

      # Subscribe to the topic first
      Phoenix.PubSub.subscribe(TicketSplitter.PubSub, "ticket:#{ticket_id}")

      # Broadcast the update
      TicketBroadcaster.broadcast_ticket_update(ticket_id)

      # Assert the message was received
      assert_receive {:ticket_updated, ^ticket_id}
    end
  end

  describe "broadcast_slider_lock/3" do
    test "broadcasts slider lock event" do
      ticket_id = "test-ticket-456"
      group_id = "group-abc"
      locked_by = "Alice"

      # Subscribe to the topic first
      Phoenix.PubSub.subscribe(TicketSplitter.PubSub, "ticket:#{ticket_id}")

      # Broadcast the lock
      TicketBroadcaster.broadcast_slider_lock(ticket_id, group_id, locked_by)

      # Assert the message was received
      assert_receive {:slider_locked, ^group_id, ^locked_by}
    end
  end

  describe "broadcast_slider_unlock/2" do
    test "broadcasts slider unlock event" do
      ticket_id = "test-ticket-789"
      group_id = "group-def"

      # Subscribe to the topic first
      Phoenix.PubSub.subscribe(TicketSplitter.PubSub, "ticket:#{ticket_id}")

      # Broadcast the unlock
      TicketBroadcaster.broadcast_slider_unlock(ticket_id, group_id)

      # Assert the message was received
      assert_receive {:slider_unlocked, ^group_id}
    end
  end
end
