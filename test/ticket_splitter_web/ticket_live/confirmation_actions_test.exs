defmodule TicketSplitterWeb.TicketLive.ConfirmationActionsTest do
  use TicketSplitter.DataCase, async: true

  alias TicketSplitterWeb.TicketLive.ConfirmationActions

  describe "show_unshare_confirmation_assigns/1" do
    test "returns assigns for unshare confirmation" do
      params = %{action: "unshare"}

      assigns = ConfirmationActions.show_unshare_confirmation_assigns(params)

      assert assigns[:show_unshare_confirmation] == true
      assert assigns[:pending_share_action] == params
    end
  end

  describe "hide_unshare_confirmation_assigns/0" do
    test "returns assigns to hide unshare confirmation" do
      assigns = ConfirmationActions.hide_unshare_confirmation_assigns()

      assert assigns[:show_unshare_confirmation] == false
      assert assigns[:pending_share_action] == nil
    end
  end

  describe "show_share_confirmation_assigns/1" do
    test "returns assigns for share confirmation" do
      params = %{action: "share"}

      assigns = ConfirmationActions.show_share_confirmation_assigns(params)

      assert assigns[:show_share_confirmation] == true
      assert assigns[:pending_share_action] == params
    end
  end

  describe "hide_share_confirmation_assigns/0" do
    test "returns assigns to hide share confirmation" do
      assigns = ConfirmationActions.hide_share_confirmation_assigns()

      assert assigns[:show_share_confirmation] == false
      assert assigns[:pending_share_action] == nil
    end
  end
end
