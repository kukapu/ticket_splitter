defmodule TicketSplitter.Tickets.TicketColorManagerTest do
  use TicketSplitter.DataCase

  alias TicketSplitter.Tickets.TicketColorManager

  describe "get_deterministic_color/2" do
    test "returns consistent color for same name" do
      existing_participants = []

      color1 = TicketColorManager.get_deterministic_color("Alice", existing_participants)
      color2 = TicketColorManager.get_deterministic_color("Alice", existing_participants)

      assert color1 == color2
    end

    test "returns different colors for different names" do
      existing_participants = []

      color1 = TicketColorManager.get_deterministic_color("Alice", existing_participants)
      color2 = TicketColorManager.get_deterministic_color("Bob", existing_participants)

      assert color1 != color2
    end

    test "avoids colors already in use" do
      # First participant gets a color
      color1 = TicketColorManager.get_deterministic_color("Alice", [])

      # Second participant should get a different color
      color2 = TicketColorManager.get_deterministic_color("Bob", [%{name: "Alice", color: color1}])

      assert color2 != color1
      assert color2 in TicketColorManager.colors()
    end

    test "cycles through colors when all are used" do
      all_colors = TicketColorManager.colors()

      # Create participants with all colors except one
      used_colors = Enum.take(all_colors, length(all_colors) - 1)
      existing_participants =
        Enum.with_index(used_colors, fn color, index ->
          %{name: "Participant#{index}", color: color}
        end)

      # Next participant should get the remaining color
      new_color = TicketColorManager.get_deterministic_color("NewUser", existing_participants)

      assert new_color in TicketColorManager.colors()
      assert new_color not in used_colors
    end
  end

  describe "get_available_color_from_index/2" do
    test "returns color at starting index if not used" do
      color = TicketColorManager.get_available_color_from_index(0, [])

      assert color == TicketColorManager.colors() |> Enum.at(0)
    end

    test "skips used colors" do
      all_colors = TicketColorManager.colors()
      first_color = Enum.at(all_colors, 0)

      # Use the first color
      result = TicketColorManager.get_available_color_from_index(0, [first_color])

      # Should return the second color
      assert result == Enum.at(all_colors, 1)
    end

    test "wraps around when reaching end of palette" do
      all_colors = TicketColorManager.colors()
      last_color = List.last(all_colors)

      # All colors are used except the first one
      result = TicketColorManager.get_available_color_from_index(length(all_colors) - 1, [last_color])

      # Should wrap around to find an available color
      assert result in all_colors
    end
  end

  describe "colors/0" do
    test "returns all available colors" do
      colors = TicketColorManager.colors()

      assert is_list(colors)
      assert length(colors) == 15
      assert Enum.all?(colors, fn color -> String.starts_with?(color, "#") end)
    end
  end
end
