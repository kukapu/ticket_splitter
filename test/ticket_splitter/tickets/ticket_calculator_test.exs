defmodule TicketSplitter.Tickets.TicketCalculatorTest do
  use TicketSplitter.DataCase

  alias TicketSplitter.Tickets.TicketCalculator

  describe "calculate_ticket_total/1" do
    test "calculates total of all products" do
      products = [
        %{total_price: Decimal.new("10.50")},
        %{total_price: Decimal.new("5.25")},
        %{total_price: Decimal.new("3.00")}
      ]

      assert TicketCalculator.calculate_ticket_total(products) == Decimal.new("18.75")
    end

    test "returns 0 for empty product list" do
      assert TicketCalculator.calculate_ticket_total([]) == Decimal.new("0")
    end

    test "handles zero prices correctly" do
      products = [
        %{total_price: Decimal.new("0")},
        %{total_price: Decimal.new("10.00")}
      ]

      assert TicketCalculator.calculate_ticket_total(products) == Decimal.new("10.00")
    end
  end

  describe "calculate_total_assigned/2" do
    test "calculates assigned units cost" do
      products = [
        %{
          total_price: Decimal.new("10.00"),
          units: 10,
          is_common: false,
          common_units: Decimal.new("0"),
          participant_assignments: [
            %{
              assignment_group_id: "group1",
              units_assigned: Decimal.new("5")
            },
            %{
              assignment_group_id: "group2",
              units_assigned: Decimal.new("3")
            }
          ]
        }
      ]

      result = TicketCalculator.calculate_total_assigned(products, 2)
      # 5 units + 3 units = 8 units * 1.00 per unit = 8.00
      assert Decimal.equal?(result, Decimal.new("8.00"))
    end

    test "handles legacy is_common products" do
      products = [
        %{
          total_price: Decimal.new("10.00"),
          units: 10,
          is_common: true,
          common_units: Decimal.new("0"),
          participant_assignments: []
        }
      ]

      result = TicketCalculator.calculate_total_assigned(products, 2)
      # Legacy is_common products count their total price
      assert Decimal.equal?(result, Decimal.new("10.00"))
    end

    test "handles new common_units products" do
      products = [
        %{
          total_price: Decimal.new("10.00"),
          units: 10,
          is_common: false,
          common_units: Decimal.new("5"),
          participant_assignments: []
        }
      ]

      result = TicketCalculator.calculate_total_assigned(products, 2)
      # 5 common units * 1.00 per unit = 5.00
      assert Decimal.equal?(result, Decimal.new("5.00"))
    end
  end

  describe "calculate_total_common/1" do
    test "calculates total common cost" do
      products = [
        %{
          total_price: Decimal.new("10.00"),
          units: 10,
          is_common: true,
          common_units: Decimal.new("0"),
          participant_assignments: []
        },
        %{
          total_price: Decimal.new("5.00"),
          units: 5,
          is_common: false,
          common_units: Decimal.new("2"),
          participant_assignments: []
        }
      ]

      result = TicketCalculator.calculate_total_common(products)
      # First product: 10.00 (is_common)
      # Second product: 2 common units * 1.00 = 2.00
      # Total: 12.00
      assert Decimal.equal?(result, Decimal.new("12.00"))
    end

    test "returns 0 for products with no common allocation" do
      products = [
        %{
          total_price: Decimal.new("10.00"),
          units: 10,
          is_common: false,
          common_units: Decimal.new("0"),
          participant_assignments: [
            %{assignment_group_id: "group1", units_assigned: Decimal.new("5")}
          ]
        }
      ]

      assert TicketCalculator.calculate_total_common(products) == Decimal.new("0")
    end
  end

  describe "calculate_common_cost/2" do
    test "divides legacy is_common product among participants" do
      product = %{
        total_price: Decimal.new("10.00"),
        units: 10,
        is_common: true,
        common_units: Decimal.new("0")
      }

      result = TicketCalculator.calculate_common_cost(product, 2)

      assert Decimal.equal?(result, Decimal.new("5.00"))
    end

    test "divides new common_units among participants" do
      product = %{
        total_price: Decimal.new("10.00"),
        units: 10,
        is_common: false,
        common_units: Decimal.new("5")
      }

      result = TicketCalculator.calculate_common_cost(product, 2)

      # 5 units * (10.00 / 10 units per unit) = 5.00 total / 2 participants = 2.50
      assert Decimal.equal?(result, Decimal.new("2.50"))
    end

    test "returns 0 when product is not common" do
      product = %{
        total_price: Decimal.new("10.00"),
        units: 10,
        is_common: false,
        common_units: Decimal.new("0")
      }

      result = TicketCalculator.calculate_common_cost(product, 2)

      assert Decimal.equal?(result, Decimal.new("0"))
    end

    test "uses whichever is greater (legacy or new)" do
      product = %{
        total_price: Decimal.new("10.00"),
        units: 10,
        is_common: true,
        common_units: Decimal.new("8")
      }

      result = TicketCalculator.calculate_common_cost(product, 2)

      # Legacy: 10.00 / 2 = 5.00
      # New: 8 * (10.00 / 10) / 2 = 4.00
      # Should use legacy (5.00 > 4.00)
      assert Decimal.equal?(result, Decimal.new("5.00"))
    end
  end

  describe "calculate_personal_cost/2" do
    test "calculates cost for participant with assignment" do
      product = %{
        total_price: Decimal.new("10.00"),
        units: 10,
        participant_assignments: [
          %{
            participant_name: "Alice",
            units_assigned: Decimal.new("3"),
            percentage: Decimal.new("100")
          }
        ]
      }

      result = TicketCalculator.calculate_personal_cost(product, "Alice")

      # 3 units * (10.00 / 10 units per unit) = 3.00
      assert Decimal.equal?(result, Decimal.new("3.00"))
    end

    test "applies percentage for shared groups" do
      product = %{
        total_price: Decimal.new("10.00"),
        units: 10,
        participant_assignments: [
          %{
            participant_name: "Alice",
            units_assigned: Decimal.new("3"),
            percentage: Decimal.new("50")
          }
        ]
      }

      result = TicketCalculator.calculate_personal_cost(product, "Alice")

      # 3 units * (10.00 / 10) = 3.00 * 50% = 1.50
      assert Decimal.equal?(result, Decimal.new("1.50"))
    end

    test "returns 0 when participant has no assignment" do
      product = %{
        total_price: Decimal.new("10.00"),
        units: 10,
        participant_assignments: [
          %{
            participant_name: "Bob",
            units_assigned: Decimal.new("3"),
            percentage: Decimal.new("100")
          }
        ]
      }

      result = TicketCalculator.calculate_personal_cost(product, "Alice")

      assert Decimal.equal?(result, Decimal.new("0"))
    end
  end

  describe "calculate_common_cost_with_multiplier/3" do
    test "multiplies common share by multiplier for legacy is_common" do
      product = %{
        total_price: Decimal.new("10.00"),
        units: 10,
        is_common: true,
        common_units: Decimal.new("0")
      }

      result = TicketCalculator.calculate_common_cost_with_multiplier(product, 2, 3)

      # Base: 10.00 / 2 = 5.00
      # With multiplier 3: 5.00 * 3 = 15.00
      assert Decimal.equal?(result, Decimal.new("15.00"))
    end

    test "multiplies common share by multiplier for new common_units" do
      product = %{
        total_price: Decimal.new("10.00"),
        units: 10,
        is_common: false,
        common_units: Decimal.new("5")
      }

      result = TicketCalculator.calculate_common_cost_with_multiplier(product, 2, 3)

      # Base: (5 * 1.00) / 2 = 2.50
      # With multiplier 3: 2.50 * 3 = 7.50
      assert Decimal.equal?(result, Decimal.new("7.50"))
    end

    test "returns 0 when product is not common" do
      product = %{
        total_price: Decimal.new("10.00"),
        units: 10,
        is_common: false,
        common_units: Decimal.new("0")
      }

      result = TicketCalculator.calculate_common_cost_with_multiplier(product, 2, 3)

      assert Decimal.equal?(result, Decimal.new("0"))
    end
  end
end
