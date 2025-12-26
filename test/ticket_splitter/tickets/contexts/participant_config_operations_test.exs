defmodule TicketSplitter.Tickets.Contexts.ParticipantConfigOperationsTest do
  use TicketSplitter.DataCase, async: true

  alias TicketSplitter.Tickets.Contexts.ParticipantConfigOperations
  alias TicketSplitter.TicketsFixtures

  describe "get_participant_config/2" do
    test "returns config when exists" do
      ticket = TicketsFixtures.ticket_fixture()

      config =
        TicketsFixtures.participant_config_fixture(
          ticket_id: ticket.id,
          participant_name: "Alice",
          multiplier: 3
        )

      retrieved = ParticipantConfigOperations.get_participant_config(ticket.id, "Alice")

      assert retrieved.id == config.id
      assert retrieved.multiplier == 3
    end

    test "returns nil when config does not exist" do
      ticket = TicketsFixtures.ticket_fixture()

      assert ParticipantConfigOperations.get_participant_config(ticket.id, "Alice") == nil
    end

    test "trims whitespace from participant name" do
      ticket = TicketsFixtures.ticket_fixture()

      TicketsFixtures.participant_config_fixture(
        ticket_id: ticket.id,
        participant_name: "Alice",
        multiplier: 2
      )

      assert ParticipantConfigOperations.get_participant_config(ticket.id, "  Alice  ") != nil
    end
  end

  describe "get_or_create_participant_config/2" do
    test "returns existing config when exists" do
      ticket = TicketsFixtures.ticket_fixture()

      config =
        TicketsFixtures.participant_config_fixture(
          ticket_id: ticket.id,
          participant_name: "Alice",
          multiplier: 5
        )

      assert {:ok, retrieved} =
               ParticipantConfigOperations.get_or_create_participant_config(ticket.id, "Alice")

      assert retrieved.id == config.id
      assert retrieved.multiplier == 5
    end

    test "creates new config with multiplier=1 when not exists" do
      ticket = TicketsFixtures.ticket_fixture()

      assert {:ok, config} =
               ParticipantConfigOperations.get_or_create_participant_config(ticket.id, "Alice")

      assert config.participant_name == "Alice"
      assert config.multiplier == 1
      assert config.ticket_id == ticket.id
    end

    test "trims whitespace from participant name" do
      ticket = TicketsFixtures.ticket_fixture()

      assert {:ok, config} =
               ParticipantConfigOperations.get_or_create_participant_config(
                 ticket.id,
                 "  Alice  "
               )

      assert config.participant_name == "Alice"
    end
  end

  describe "update_participant_multiplier/3" do
    test "creates config with multiplier when doesn't exist" do
      ticket = TicketsFixtures.ticket_fixture()

      assert {:ok, config} =
               ParticipantConfigOperations.update_participant_multiplier(ticket.id, "Alice", 3)

      assert config.participant_name == "Alice"
      assert config.multiplier == 3
    end

    test "updates existing config multiplier" do
      ticket = TicketsFixtures.ticket_fixture()

      TicketsFixtures.participant_config_fixture(
        ticket_id: ticket.id,
        participant_name: "Alice",
        multiplier: 1
      )

      assert {:ok, updated} =
               ParticipantConfigOperations.update_participant_multiplier(ticket.id, "Alice", 5)

      assert updated.multiplier == 5
    end

    test "accepts multiplier from 1 to 10" do
      ticket = TicketsFixtures.ticket_fixture()

      for multiplier <- 1..10 do
        assert {:ok, config} =
                 ParticipantConfigOperations.update_participant_multiplier(
                   ticket.id,
                   "Participant#{multiplier}",
                   multiplier
                 )

        assert config.multiplier == multiplier
      end
    end

    test "returns error for multiplier < 1" do
      ticket = TicketsFixtures.ticket_fixture()

      assert {:error, _changeset} =
               ParticipantConfigOperations.update_participant_multiplier(ticket.id, "Alice", 0)
    end

    test "returns error for multiplier > 10" do
      ticket = TicketsFixtures.ticket_fixture()

      assert {:error, _changeset} =
               ParticipantConfigOperations.update_participant_multiplier(ticket.id, "Alice", 11)
    end

    test "trims whitespace from participant name" do
      ticket = TicketsFixtures.ticket_fixture()

      assert {:ok, config} =
               ParticipantConfigOperations.update_participant_multiplier(
                 ticket.id,
                 "  Alice  ",
                 3
               )

      assert config.participant_name == "Alice"
    end
  end

  describe "get_participant_multiplier/2" do
    test "returns multiplier from config when exists" do
      ticket = TicketsFixtures.ticket_fixture()

      TicketsFixtures.participant_config_fixture(
        ticket_id: ticket.id,
        participant_name: "Alice",
        multiplier: 5
      )

      assert ParticipantConfigOperations.get_participant_multiplier(ticket.id, "Alice") == 5
    end

    test "returns 1 when no config exists" do
      ticket = TicketsFixtures.ticket_fixture()

      assert ParticipantConfigOperations.get_participant_multiplier(ticket.id, "Alice") == 1
    end

    test "trims whitespace from participant name" do
      ticket = TicketsFixtures.ticket_fixture()

      TicketsFixtures.participant_config_fixture(
        ticket_id: ticket.id,
        participant_name: "Alice",
        multiplier: 3
      )

      assert ParticipantConfigOperations.get_participant_multiplier(ticket.id, "  Alice  ") == 3
    end
  end

  describe "list_participant_configs/1" do
    test "returns empty list when no configs exist" do
      ticket = TicketsFixtures.ticket_fixture()

      assert ParticipantConfigOperations.list_participant_configs(ticket.id) == []
    end

    test "returns all configs for a ticket" do
      ticket = TicketsFixtures.ticket_fixture()

      TicketsFixtures.participant_config_fixture(
        ticket_id: ticket.id,
        participant_name: "Alice",
        multiplier: 2
      )

      TicketsFixtures.participant_config_fixture(
        ticket_id: ticket.id,
        participant_name: "Bob",
        multiplier: 3
      )

      configs = ParticipantConfigOperations.list_participant_configs(ticket.id)

      assert length(configs) == 2
    end

    test "does not return configs from other tickets" do
      ticket1 = TicketsFixtures.ticket_fixture()
      ticket2 = TicketsFixtures.ticket_fixture()

      TicketsFixtures.participant_config_fixture(
        ticket_id: ticket1.id,
        participant_name: "Alice",
        multiplier: 2
      )

      TicketsFixtures.participant_config_fixture(
        ticket_id: ticket2.id,
        participant_name: "Alice",
        multiplier: 3
      )

      configs = ParticipantConfigOperations.list_participant_configs(ticket1.id)

      assert length(configs) == 1
    end
  end

  describe "get_effective_participants_count/1" do
    test "returns 3 for ticket with 3 participants with multiplier 1" do
      ticket = TicketsFixtures.ticket_fixture(total_participants: 3)
      product = TicketsFixtures.product_fixture(ticket_id: ticket.id)

      for name <- ["Alice", "Bob", "Charlie"] do
        TicketsFixtures.participant_assignment_fixture(
          product_id: product.id,
          participant_name: name,
          units_assigned: Decimal.new("1")
        )
      end

      assert ParticipantConfigOperations.get_effective_participants_count(ticket.id) == 3
    end

    test "returns 5 for [Alice:1x, Bob:2x, Charlie:2x] = 1+2+2" do
      ticket = TicketsFixtures.ticket_fixture(total_participants: 3)
      product = TicketsFixtures.product_fixture(ticket_id: ticket.id)

      for name <- ["Alice", "Bob", "Charlie"] do
        TicketsFixtures.participant_assignment_fixture(
          product_id: product.id,
          participant_name: name,
          units_assigned: Decimal.new("1")
        )
      end

      TicketsFixtures.participant_config_fixture(
        ticket_id: ticket.id,
        participant_name: "Bob",
        multiplier: 2
      )

      TicketsFixtures.participant_config_fixture(
        ticket_id: ticket.id,
        participant_name: "Charlie",
        multiplier: 2
      )

      assert ParticipantConfigOperations.get_effective_participants_count(ticket.id) == 5
    end

    test "returns 19 for [Alice:10x] with 9 non-active participants" do
      ticket = TicketsFixtures.ticket_fixture(total_participants: 10)
      product = TicketsFixtures.product_fixture(ticket_id: ticket.id)

      TicketsFixtures.participant_assignment_fixture(
        product_id: product.id,
        participant_name: "Alice",
        units_assigned: Decimal.new("1")
      )

      TicketsFixtures.participant_config_fixture(
        ticket_id: ticket.id,
        participant_name: "Alice",
        multiplier: 10
      )

      assert ParticipantConfigOperations.get_effective_participants_count(ticket.id) == 19
    end

    test "returns total_participants for ticket with no active participants" do
      ticket = TicketsFixtures.ticket_fixture(total_participants: 5)

      assert ParticipantConfigOperations.get_effective_participants_count(ticket.id) == 5
    end

    test "includes non-active participants with multiplier of 1" do
      ticket = TicketsFixtures.ticket_fixture(total_participants: 5)
      product = TicketsFixtures.product_fixture(ticket_id: ticket.id)

      TicketsFixtures.participant_assignment_fixture(
        product_id: product.id,
        participant_name: "Alice",
        units_assigned: Decimal.new("1")
      )

      assert ParticipantConfigOperations.get_effective_participants_count(ticket.id) == 5
    end
  end

  describe "calculate_participant_total_with_multiplier/2" do
    test "multiplies individual total by multiplier" do
      ticket = TicketsFixtures.ticket_fixture(total_participants: 3)

      product =
        TicketsFixtures.product_fixture(
          ticket_id: ticket.id,
          units: 3,
          total_price: Decimal.new("30.00"),
          is_common: true
        )

      TicketsFixtures.participant_config_fixture(
        ticket_id: ticket.id,
        participant_name: "Alice",
        multiplier: 3
      )

      total =
        ParticipantConfigOperations.calculate_participant_total_with_multiplier(
          ticket.id,
          "Alice"
        )

      assert Decimal.equal?(total, Decimal.new("30.00"))
    end

    test "handles multiplier = 1 (no change)" do
      ticket = TicketsFixtures.ticket_fixture(total_participants: 3)

      product =
        TicketsFixtures.product_fixture(
          ticket_id: ticket.id,
          units: 3,
          total_price: Decimal.new("30.00"),
          is_common: true
        )

      TicketsFixtures.participant_config_fixture(
        ticket_id: ticket.id,
        participant_name: "Alice",
        multiplier: 1
      )

      total =
        ParticipantConfigOperations.calculate_participant_total_with_multiplier(
          ticket.id,
          "Alice"
        )

      assert Decimal.equal?(total, Decimal.new("10.00"))
    end

    test "handles multiplier = 5 (5x individual total)" do
      ticket = TicketsFixtures.ticket_fixture(total_participants: 5)

      product =
        TicketsFixtures.product_fixture(
          ticket_id: ticket.id,
          units: 5,
          total_price: Decimal.new("50.00"),
          is_common: true
        )

      TicketsFixtures.participant_config_fixture(
        ticket_id: ticket.id,
        participant_name: "Alice",
        multiplier: 5
      )

      total =
        ParticipantConfigOperations.calculate_participant_total_with_multiplier(
          ticket.id,
          "Alice"
        )

      assert Decimal.equal?(total, Decimal.new("50.00"))
    end

    test "works with Decimal amounts correctly" do
      ticket = TicketsFixtures.ticket_fixture(total_participants: 3)

      product =
        TicketsFixtures.product_fixture(
          ticket_id: ticket.id,
          units: 3,
          total_price: Decimal.new("31.50"),
          is_common: true
        )

      TicketsFixtures.participant_config_fixture(
        ticket_id: ticket.id,
        participant_name: "Alice",
        multiplier: 2
      )

      total =
        ParticipantConfigOperations.calculate_participant_total_with_multiplier(
          ticket.id,
          "Alice"
        )

      assert Decimal.equal?(total, Decimal.new("21.00"))
    end
  end

  describe "calculate_participant_total/2" do
    test "calculates total without multiplier for participant with personal assignment" do
      ticket = TicketsFixtures.ticket_fixture(total_participants: 2)

      product =
        TicketsFixtures.product_fixture(
          ticket_id: ticket.id,
          units: 10,
          total_price: Decimal.new("100.00"),
          is_common: false
        )

      TicketsFixtures.participant_assignment_fixture(
        product_id: product.id,
        participant_name: "Alice",
        units_assigned: Decimal.new("6"),
        percentage: Decimal.new("100")
      )

      total = ParticipantConfigOperations.calculate_participant_total(ticket.id, "Alice")

      # 6 units * 10.00 per unit = 60.00
      assert Decimal.equal?(total, Decimal.new("60.00"))
    end

    test "includes common products in total" do
      ticket = TicketsFixtures.ticket_fixture(total_participants: 3)

      # Common product (legacy is_common: true)
      product1 =
        TicketsFixtures.product_fixture(
          ticket_id: ticket.id,
          total_price: Decimal.new("30.00"),
          is_common: true
        )

      # Personal product
      product2 =
        TicketsFixtures.product_fixture(
          ticket_id: ticket.id,
          units: 10,
          total_price: Decimal.new("50.00"),
          is_common: false
        )

      TicketsFixtures.participant_assignment_fixture(
        product_id: product2.id,
        participant_name: "Alice",
        units_assigned: Decimal.new("5"),
        percentage: Decimal.new("100")
      )

      total = ParticipantConfigOperations.calculate_participant_total(ticket.id, "Alice")

      # Common: 30/3 = 10.00
      # Personal: 5 * 5.00 = 25.00
      # Total: 35.00
      assert Decimal.equal?(total, Decimal.new("35.00"))
    end

    test "includes new common_units products in total" do
      ticket = TicketsFixtures.ticket_fixture(total_participants: 4)

      # Product with common_units (new system)
      product =
        TicketsFixtures.product_fixture(
          ticket_id: ticket.id,
          units: 10,
          total_price: Decimal.new("40.00"),
          is_common: false,
          common_units: Decimal.new("4")
        )

      total = ParticipantConfigOperations.calculate_participant_total(ticket.id, "Bob")

      # Common units: 4 * 4.00 per unit = 16.00, divided by 4 participants = 4.00
      # Bob has no personal assignment, so total is just common share
      assert Decimal.equal?(total, Decimal.new("4.00"))
    end

    test "calculates correctly with both personal and common assignments" do
      ticket = TicketsFixtures.ticket_fixture(total_participants: 2)

      # Product with both personal and common
      product =
        TicketsFixtures.product_fixture(
          ticket_id: ticket.id,
          units: 10,
          total_price: Decimal.new("100.00"),
          is_common: false,
          common_units: Decimal.new("2")
        )

      TicketsFixtures.participant_assignment_fixture(
        product_id: product.id,
        participant_name: "Alice",
        units_assigned: Decimal.new("3"),
        percentage: Decimal.new("100")
      )

      total = ParticipantConfigOperations.calculate_participant_total(ticket.id, "Alice")

      # Personal: 3 units * 10.00 per unit = 30.00
      # Common: (2 units * 10.00 per unit) / 2 participants = 10.00
      # Total: 40.00
      assert Decimal.equal?(total, Decimal.new("40.00"))
    end

    test "returns zero for participant with no assignments and no common products" do
      ticket = TicketsFixtures.ticket_fixture(total_participants: 3)

      product =
        TicketsFixtures.product_fixture(
          ticket_id: ticket.id,
          units: 10,
          total_price: Decimal.new("50.00"),
          is_common: false
        )

      TicketsFixtures.participant_assignment_fixture(
        product_id: product.id,
        participant_name: "Bob",
        units_assigned: Decimal.new("5"),
        percentage: Decimal.new("100")
      )

      total = ParticipantConfigOperations.calculate_participant_total(ticket.id, "Charlie")

      # Charlie has no assignments and there are no common products
      assert Decimal.equal?(total, Decimal.new("0"))
    end

    test "calculates correctly with multiple products" do
      ticket = TicketsFixtures.ticket_fixture(total_participants: 2)

      # Product 1: Personal assignment
      product1 =
        TicketsFixtures.product_fixture(
          ticket_id: ticket.id,
          units: 5,
          total_price: Decimal.new("25.00"),
          is_common: false
        )

      TicketsFixtures.participant_assignment_fixture(
        product_id: product1.id,
        participant_name: "Alice",
        units_assigned: Decimal.new("2"),
        percentage: Decimal.new("100")
      )

      # Product 2: Common
      product2 =
        TicketsFixtures.product_fixture(
          ticket_id: ticket.id,
          total_price: Decimal.new("20.00"),
          is_common: true
        )

      # Product 3: Another personal
      product3 =
        TicketsFixtures.product_fixture(
          ticket_id: ticket.id,
          units: 10,
          total_price: Decimal.new("50.00"),
          is_common: false
        )

      TicketsFixtures.participant_assignment_fixture(
        product_id: product3.id,
        participant_name: "Alice",
        units_assigned: Decimal.new("3"),
        percentage: Decimal.new("100")
      )

      total = ParticipantConfigOperations.calculate_participant_total(ticket.id, "Alice")

      # Product 1: 2 * 5.00 = 10.00
      # Product 2: 20.00 / 2 = 10.00
      # Product 3: 3 * 5.00 = 15.00
      # Total: 35.00
      assert Decimal.equal?(total, Decimal.new("35.00"))
    end

    test "handles shared assignments (percentage < 100)" do
      ticket = TicketsFixtures.ticket_fixture(total_participants: 2)

      product =
        TicketsFixtures.product_fixture(
          ticket_id: ticket.id,
          units: 10,
          total_price: Decimal.new("100.00"),
          is_common: false
        )

      # Alice and Bob share 5 units (50/50)
      group_id = Ecto.UUID.generate()

      TicketsFixtures.participant_assignment_fixture(
        product_id: product.id,
        participant_name: "Alice",
        units_assigned: Decimal.new("5"),
        percentage: Decimal.new("50"),
        assignment_group_id: group_id
      )

      TicketsFixtures.participant_assignment_fixture(
        product_id: product.id,
        participant_name: "Bob",
        units_assigned: Decimal.new("5"),
        percentage: Decimal.new("50"),
        assignment_group_id: group_id
      )

      total = ParticipantConfigOperations.calculate_participant_total(ticket.id, "Alice")

      # 5 units * 10.00 per unit * 50% = 25.00
      assert Decimal.equal?(total, Decimal.new("25.00"))
    end

    test "trims whitespace from participant name" do
      ticket = TicketsFixtures.ticket_fixture(total_participants: 2)

      product =
        TicketsFixtures.product_fixture(
          ticket_id: ticket.id,
          units: 10,
          total_price: Decimal.new("100.00"),
          is_common: false
        )

      TicketsFixtures.participant_assignment_fixture(
        product_id: product.id,
        participant_name: "Alice",
        units_assigned: Decimal.new("4"),
        percentage: Decimal.new("100")
      )

      total = ParticipantConfigOperations.calculate_participant_total(ticket.id, "  Alice  ")

      assert Decimal.equal?(total, Decimal.new("40.00"))
    end

    test "returns zero for ticket with no products" do
      ticket = TicketsFixtures.ticket_fixture(total_participants: 3)

      total = ParticipantConfigOperations.calculate_participant_total(ticket.id, "Alice")

      assert Decimal.equal?(total, Decimal.new("0"))
    end
  end
end
