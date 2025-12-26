defmodule TicketSplitterWeb.TicketLive.TerminateActionsTest do
  use TicketSplitter.DataCase, async: true

  alias TicketSplitterWeb.TicketLive.TerminateActions

  alias TicketSplitter.Tickets
  import TicketSplitter.TicketsFixtures

  describe "unlock_participant_sliders/3" do
    test "unlocks sliders locked by participant" do
      ticket = ticket_fixture()
      participant_name = "Alice"

      locked_sliders = %{
        "product-1" => "Alice",
        "product-2" => "Bob",
        "product-3" => "Alice"
      }

      result =
        TerminateActions.unlock_participant_sliders(
          ticket.id,
          participant_name,
          locked_sliders
        )

      assert result == :ok
    end

    test "does nothing when participant_name is nil" do
      ticket = ticket_fixture()

      locked_sliders = %{
        "product-1" => "Alice"
      }

      result =
        TerminateActions.unlock_participant_sliders(ticket.id, nil, locked_sliders)

      assert result == :ok
    end

    test "does not unlock sliders locked by other participants" do
      ticket = ticket_fixture()
      participant_name = "Alice"

      locked_sliders = %{
        "product-1" => "Bob",
        "product-2" => "Charlie"
      }

      result =
        TerminateActions.unlock_participant_sliders(
          ticket.id,
          participant_name,
          locked_sliders
        )

      assert result == :ok
    end
  end
end
