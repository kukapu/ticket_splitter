defmodule TicketSplitter.Tickets.TicketColorManagerTest do
  use TicketSplitter.DataCase

  alias TicketSplitter.Tickets.TicketColorManager
  alias TicketSplitter.TicketsFixtures

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
      color1 = TicketColorManager.get_deterministic_color("Alice", [])

      color2 =
        TicketColorManager.get_deterministic_color("Bob", [%{name: "Alice", color: color1}])

      assert color2 != color1
      assert color2 in TicketColorManager.colors()
    end

    test "handles empty participants list" do
      existing_participants = []

      color = TicketColorManager.get_deterministic_color("Alice", existing_participants)

      assert is_binary(color)
      assert String.starts_with?(color, "#")
    end

    test "returns color from palette" do
      existing_participants = []
      color = TicketColorManager.get_deterministic_color("Alice", existing_participants)

      assert color in TicketColorManager.colors()
    end

    test "skips colors that conflict with used colors" do
      existing_participants = [%{name: "Alice", color: "#FF3D00"}]

      bob_color =
        TicketColorManager.get_deterministic_color("Bob", existing_participants)

      refute bob_color == "#FF3D00"
      assert bob_color in TicketColorManager.colors()
    end
  end

  describe "get_available_color_from_index/2" do
    test "returns color at starting index when available" do
      used_colors = []

      color = TicketColorManager.get_available_color_from_index(0, used_colors)

      assert is_binary(color)
      assert String.starts_with?(color, "#")
    end

    test "skips used colors" do
      all_colors = TicketColorManager.colors()
      first_color = Enum.at(all_colors, 0)

      color = TicketColorManager.get_available_color_from_index(0, [first_color])

      refute color == first_color
      assert color in all_colors
      refute color in [first_color]
    end

    test "handles empty used_colors" do
      used_colors = []

      color = TicketColorManager.get_available_color_from_index(0, used_colors)

      assert is_binary(color)
      assert String.starts_with?(color, "#")
      assert color == List.first(TicketColorManager.colors())
    end

    test "handles multiple consecutive used colors" do
      all_colors = TicketColorManager.colors()
      used_colors = Enum.take(all_colors, 5)

      color = TicketColorManager.get_available_color_from_index(0, used_colors)

      refute color in used_colors
      assert color in all_colors
    end

    test "handles wrap around when all preceding colors are used" do
      all_colors = TicketColorManager.colors()
      used_colors = Enum.take(all_colors, length(all_colors) - 1)

      color =
        TicketColorManager.get_available_color_from_index(length(all_colors) - 1, used_colors)

      refute color in used_colors
      assert color in all_colors
    end
  end

  describe "colors/0" do
    test "returns all available colors" do
      colors = TicketColorManager.colors()

      assert is_list(colors)
      assert length(colors) == 15
    end

    test "returns valid hex colors" do
      colors = TicketColorManager.colors()

      Enum.each(colors, fn color ->
        assert String.starts_with?(color, "#")
        assert String.length(color) == 7
      end)
    end
  end

  describe "get_existing_user_color/2" do
    test "returns color when participant has assignments" do
      ticket = TicketsFixtures.ticket_fixture()
      product = TicketsFixtures.product_fixture(ticket_id: ticket.id)

      TicketsFixtures.participant_assignment_fixture(
        product_id: product.id,
        participant_name: "Alice",
        assigned_color: "#FF3D00"
      )

      color = TicketColorManager.get_existing_user_color(ticket.id, "Alice")

      assert color == "#FF3D00"
    end

    test "returns first color when participant has multiple assignments" do
      ticket = TicketsFixtures.ticket_fixture()
      product1 = TicketsFixtures.product_fixture(ticket_id: ticket.id)
      product2 = TicketsFixtures.product_fixture(ticket_id: ticket.id)

      TicketsFixtures.participant_assignment_fixture(
        product_id: product1.id,
        participant_name: "Alice",
        assigned_color: "#FF9100"
      )

      TicketsFixtures.participant_assignment_fixture(
        product_id: product2.id,
        participant_name: "Alice",
        assigned_color: "#FFD600"
      )

      color = TicketColorManager.get_existing_user_color(ticket.id, "Alice")

      assert color == "#FF9100"
    end

    test "returns nil when participant has no assignments" do
      ticket = TicketsFixtures.ticket_fixture()

      color = TicketColorManager.get_existing_user_color(ticket.id, "Alice")

      assert is_nil(color)
    end

    test "returns nil when participant has assignments in other ticket" do
      ticket1 = TicketsFixtures.ticket_fixture()
      ticket2 = TicketsFixtures.ticket_fixture()
      product1 = TicketsFixtures.product_fixture(ticket_id: ticket1.id)

      TicketsFixtures.participant_assignment_fixture(
        product_id: product1.id,
        participant_name: "Alice",
        assigned_color: "#FF3D00"
      )

      color = TicketColorManager.get_existing_user_color(ticket2.id, "Alice")

      assert is_nil(color)
    end

    test "handles multiple participants with same name in different tickets" do
      ticket1 = TicketsFixtures.ticket_fixture()
      ticket2 = TicketsFixtures.ticket_fixture()
      product1 = TicketsFixtures.product_fixture(ticket_id: ticket1.id)
      product2 = TicketsFixtures.product_fixture(ticket_id: ticket2.id)

      TicketsFixtures.participant_assignment_fixture(
        product_id: product1.id,
        participant_name: "Alice",
        assigned_color: "#FF3D00"
      )

      TicketsFixtures.participant_assignment_fixture(
        product_id: product2.id,
        participant_name: "Alice",
        assigned_color: "#FF9100"
      )

      color1 = TicketColorManager.get_existing_user_color(ticket1.id, "Alice")
      color2 = TicketColorManager.get_existing_user_color(ticket2.id, "Alice")

      assert color1 == "#FF3D00"
      assert color2 == "#FF9100"
      assert color1 != color2
    end
  end
end
