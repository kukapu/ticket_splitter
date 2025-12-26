defmodule TicketSplitterWeb.TicketLive.SummaryModalTest do
  use TicketSplitterWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias TicketSplitterWeb.TicketLive.SummaryModal

  describe "render/1" do
    test "renders summary modal" do
      assigns = %{
        id: "summary-modal",
        participants_for_summary: [%{name: "Alice", total: 10, color: "#000000"}],
        summary_tab: "summary",
        participant_name: "Alice",
        my_multiplier: 1,
        acting_as_participant: nil,
        total_ticket: Decimal.new("20.00"),
        total_assigned: Decimal.new("10.00"),
        pending: Decimal.new("10.00")
      }

      html = render_component(&SummaryModal.render/1, assigns)

      assert html =~ "Summary"
      assert html =~ "Participants"
    end

    test "displays summary tab content" do
      assigns = %{
        id: "summary-modal",
        participants_for_summary: [%{name: "Alice", total: 10, color: "#000000"}],
        summary_tab: "summary",
        participant_name: "Alice",
        my_multiplier: 1,
        acting_as_participant: nil,
        total_ticket: Decimal.new("20.00"),
        total_assigned: Decimal.new("10.00"),
        pending: Decimal.new("10.00")
      }

      html = render_component(&SummaryModal.render/1, assigns)

      assert html =~ "I pay for"
    end

    test "shows warning border when acting_as is set" do
      assigns = %{
        id: "summary-modal",
        participants_for_summary: [],
        summary_tab: "summary",
        acting_as_participant: "Alice",
        participant_name: "Bob",
        my_multiplier: 1,
        acting_as_multiplier: 1,
        total_ticket: Decimal.new("20.00"),
        total_assigned: Decimal.new("10.00"),
        pending: Decimal.new("10.00")
      }

      html = render_component(&SummaryModal.render/1, assigns)

      assert html =~ "border-warning"
    end

    test "displays decrement button" do
      assigns = %{
        id: "summary-modal",
        participants_for_summary: [],
        summary_tab: "summary",
        acting_as_participant: "Alice",
        acting_as_multiplier: 2,
        participant_name: "Bob",
        my_multiplier: 1,
        total_ticket: Decimal.new("20.00"),
        total_assigned: Decimal.new("10.00"),
        pending: Decimal.new("10.00")
      }

      html = render_component(&SummaryModal.render/1, assigns)

      assert html =~ "decrement_multiplier"
    end

    test "displays increment button" do
      assigns = %{
        id: "summary-modal",
        participants_for_summary: [],
        summary_tab: "summary",
        acting_as_participant: "Alice",
        acting_as_multiplier: 2,
        participant_name: "Bob",
        my_multiplier: 1,
        total_ticket: Decimal.new("20.00"),
        total_assigned: Decimal.new("10.00"),
        pending: Decimal.new("10.00")
      }

      html = render_component(&SummaryModal.render/1, assigns)

      assert html =~ "increment_multiplier"
    end
  end
end
