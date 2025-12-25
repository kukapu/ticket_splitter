defmodule TicketSplitter.Tickets.TicketBroadcaster do
  @moduledoc """
  Handles PubSub broadcasting for ticket updates.
  Extracted from TicketLive for reusability.
  """

  @doc """
  Broadcasts ticket update to all subscribers.
  """
  def broadcast_ticket_update(ticket_id) do
    Phoenix.PubSub.broadcast(
      TicketSplitter.PubSub,
      "ticket:#{ticket_id}",
      {:ticket_updated, ticket_id}
    )
  end

  @doc """
  Broadcasts slider lock event to all subscribers.
  """
  def broadcast_slider_lock(ticket_id, group_id, locked_by) do
    Phoenix.PubSub.broadcast(
      TicketSplitter.PubSub,
      "ticket:#{ticket_id}",
      {:slider_locked, group_id, locked_by}
    )
  end

  @doc """
  Broadcasts slider unlock event to all subscribers.
  """
  def broadcast_slider_unlock(ticket_id, group_id) do
    Phoenix.PubSub.broadcast(
      TicketSplitter.PubSub,
      "ticket:#{ticket_id}",
      {:slider_unlocked, group_id}
    )
  end
end
