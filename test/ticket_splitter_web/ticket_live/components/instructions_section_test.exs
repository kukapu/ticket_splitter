defmodule TicketSplitterWeb.TicketLive.Components.InstructionsSectionTest do
  use TicketSplitterWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias TicketSplitterWeb.TicketLive.Components.InstructionsSection

  describe "instructions_section/1" do
    test "renders instructions section" do
      html =
        render_component(&InstructionsSection.instructions_section/1,
          show_instructions: false
        )

      assert html =~ "Usage instructions"
    end

    test "shows toggle button" do
      html =
        render_component(&InstructionsSection.instructions_section/1,
          show_instructions: false
        )

      assert html =~ "toggle_instructions"
      assert html =~ "chevron-down"
    end

    test "shows instructions when expanded" do
      html =
        render_component(&InstructionsSection.instructions_section/1,
          show_instructions: true
        )

      assert html =~ "+ Button"
      assert html =~ "- Button"
      assert html =~ "Common button"
    end

    test "hides instructions when collapsed" do
      html =
        render_component(&InstructionsSection.instructions_section/1,
          show_instructions: false
        )

      refute html =~ "+ Button"
    end
  end
end
