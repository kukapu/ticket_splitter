defmodule TicketSplitterWeb.TicketLive.ParticipantActionsTest do
  use TicketSplitter.DataCase, async: true

  alias TicketSplitterWeb.TicketLive.ParticipantActions

  alias TicketSplitter.Tickets
  import TicketSplitter.TicketsFixtures

  describe "calculate_increment/1" do
    test "increments count by 1" do
      result = ParticipantActions.calculate_increment(5)

      assert result == 6
    end

    test "increments zero count" do
      result = ParticipantActions.calculate_increment(0)

      assert result == 1
    end
  end

  describe "calculate_decrement/2" do
    test "decrements count" do
      result = ParticipantActions.calculate_decrement(5, 1)

      assert result == 4
    end

    test "respects minimum count" do
      result = ParticipantActions.calculate_decrement(2, 2)

      assert result == 2
    end
  end

  describe "parse_and_validate_value/2" do
    test "parses valid positive integer" do
      result = ParticipantActions.parse_and_validate_value("5", 1)

      assert result == {:ok, 5}
    end

    test "returns error for negative number" do
      result = ParticipantActions.parse_and_validate_value("-5", 1)

      assert result == :error
    end

    test "returns error for invalid input" do
      result = ParticipantActions.parse_and_validate_value("abc", 1)

      assert result == :error
    end
  end

  describe "build_basic_assigns/1" do
    test "returns basic assigns" do
      ticket = ticket_fixture()

      assigns = ParticipantActions.build_basic_assigns(ticket)

      assert assigns[:ticket] == ticket
    end
  end

  describe "build_participant_assigns/3" do
    test "builds participant assigns" do
      ticket = ticket_fixture()

      assigns = ParticipantActions.build_participant_assigns("Alice", "#FF0000", ticket)

      assert assigns[:participant_name] == "Alice"
      assert assigns[:participant_color] == "#FF0000"
      assert assigns[:ticket] == ticket
    end
  end

  describe "ghost_name_exists?/2" do
    test "returns true when ghost name exists" do
      existing_participants = [%{name: "Alice"}, %{name: "Bob"}]

      result = ParticipantActions.ghost_name_exists?(existing_participants, "Alice")

      assert result == true
    end

    test "returns false when ghost name does not exist" do
      existing_participants = [%{name: "Alice"}, %{name: "Bob"}]

      result = ParticipantActions.ghost_name_exists?(existing_participants, "Charlie")

      assert result == false
    end
  end

  describe "get_participant_by_name/2" do
    test "finds participant by name" do
      existing_participants = [%{name: "Alice"}, %{name: "Bob"}]

      result = ParticipantActions.get_participant_by_name(existing_participants, "Bob")

      assert result.name == "Bob"
    end

    test "returns nil when not found" do
      existing_participants = [%{name: "Alice"}, %{name: "Bob"}]

      result = ParticipantActions.get_participant_by_name(existing_participants, "Charlie")

      assert result == nil
    end
  end

  describe "calculate_new_participants_count/2" do
    test "increments count for new participant" do
      existing_participants = [%{name: "Alice"}]

      result =
        ParticipantActions.calculate_new_participants_count(existing_participants, "Bob")

      assert result == 2
    end

    test "does not increment for existing participant" do
      existing_participants = [%{name: "Alice"}, %{name: "Bob"}]

      result =
        ParticipantActions.calculate_new_participants_count(existing_participants, "Alice")

      assert result == 2
    end
  end

  describe "should_update_participants_count?/2" do
    test "returns should_update when new count is greater" do
      result = ParticipantActions.should_update_participants_count?(2, 3)

      assert result == {:should_update, 3}
    end

    test "returns no_update when new count is not greater" do
      result = ParticipantActions.should_update_participants_count?(3, 3)

      assert result == :no_update
    end
  end
end
