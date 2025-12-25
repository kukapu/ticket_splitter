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
end
