defmodule TicketSplitterWeb.TicketLive.ParticipantSelectorActionsTest do
  use TicketSplitter.DataCase, async: true

  alias TicketSplitterWeb.TicketLive.ParticipantSelectorActions

  describe "close_selector_assigns/0" do
    test "returns assigns to close selector" do
      assigns = ParticipantSelectorActions.close_selector_assigns()

      assert assigns[:show_participant_selector] == false
      assert assigns[:existing_participants_for_selector] == []
    end
  end

  describe "open_user_settings_assigns/0" do
    test "returns empty list for user settings" do
      assigns = ParticipantSelectorActions.open_user_settings_assigns()

      assert assigns == []
    end
  end
end
