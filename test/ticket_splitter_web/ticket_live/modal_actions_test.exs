defmodule TicketSplitterWeb.TicketLive.ModalActionsTest do
  use TicketSplitter.DataCase, async: true

  alias TicketSplitterWeb.TicketLive.ModalActions

  describe "close_modal_assigns/1" do
    test "returns assigns to close modal" do
      assigns = ModalActions.close_modal_assigns(:show_summary_modal)

      assert assigns[:show_summary_modal] == false
    end

    test "works with different modal names" do
      assigns = ModalActions.close_modal_assigns(:show_share_modal)

      assert assigns[:show_share_modal] == false
    end
  end

  describe "open_modal_assigns/1" do
    test "returns assigns to open modal" do
      assigns = ModalActions.open_modal_assigns(:show_instructions)

      assert assigns[:show_instructions] == true
    end

    test "works with different modal names" do
      assigns = ModalActions.open_modal_assigns(:show_image_modal)

      assert assigns[:show_image_modal] == true
    end
  end

  describe "toggle_modal_assigns/2" do
    test "returns assigns to toggle modal from false to true" do
      assigns = ModalActions.toggle_modal_assigns(:show_participant_selector, false)

      assert assigns[:show_participant_selector] == true
    end

    test "returns assigns to toggle modal from true to false" do
      assigns = ModalActions.toggle_modal_assigns(:show_summary_modal, true)

      assert assigns[:show_summary_modal] == false
    end
  end

  describe "editing_percentages_assigns/1" do
    test "returns assigns with product_id" do
      assigns = ModalActions.editing_percentages_assigns("product-123")

      assert assigns[:editing_percentages_product_id] == "product-123"
    end

    test "returns assigns with nil product_id" do
      assigns = ModalActions.editing_percentages_assigns(nil)

      assert assigns[:editing_percentages_product_id] == nil
    end
  end

  describe "close_editing_percentages_assigns/0" do
    test "returns assigns to close editing" do
      assigns = ModalActions.close_editing_percentages_assigns()

      assert assigns[:editing_percentages_product_id] == nil
    end
  end
end
