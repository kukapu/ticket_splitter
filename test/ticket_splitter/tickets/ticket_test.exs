defmodule TicketSplitter.Tickets.TicketTest do
  use TicketSplitter.DataCase, async: true

  alias TicketSplitter.Tickets.Ticket

  describe "changeset/2 validations" do
    setup do
      valid_attrs = %{
        total_participants: 3,
        merchant_name: "Test Merchant",
        date: ~D[2024-01-15],
        currency: "EUR",
        total_amount: Decimal.new("100.50"),
        image_url: "https://example.com/image.jpg"
      }

      %{valid_attrs: valid_attrs}
    end

    test "accepts valid attributes", %{valid_attrs: attrs} do
      changeset = Ticket.changeset(%Ticket{}, attrs)

      assert changeset.valid?
    end

    test "uses default total_participants when not provided", %{valid_attrs: attrs} do
      changeset = Ticket.changeset(%Ticket{}, Map.delete(attrs, :total_participants))

      # Should be valid because there's a default value in the schema
      assert changeset.valid?
    end

    test "accepts total_participants equal to 0", %{valid_attrs: attrs} do
      changeset = Ticket.changeset(%Ticket{}, %{attrs | total_participants: 0})

      assert changeset.valid?
    end

    test "rejects negative total_participants", %{valid_attrs: attrs} do
      changeset = Ticket.changeset(%Ticket{}, %{attrs | total_participants: -5})

      refute changeset.valid?
      assert "must be greater than or equal to 0" in errors_on(changeset).total_participants
    end

    test "accepts total_participants of 1", %{valid_attrs: attrs} do
      changeset = Ticket.changeset(%Ticket{}, %{attrs | total_participants: 1})

      assert changeset.valid?
    end

    test "accepts large number of total_participants", %{valid_attrs: attrs} do
      changeset = Ticket.changeset(%Ticket{}, %{attrs | total_participants: 1000})

      assert changeset.valid?
    end

    test "accepts nil merchant_name", %{valid_attrs: attrs} do
      changeset = Ticket.changeset(%Ticket{}, Map.put(attrs, :merchant_name, nil))

      assert changeset.valid?
    end

    test "accepts nil date", %{valid_attrs: attrs} do
      changeset = Ticket.changeset(%Ticket{}, Map.put(attrs, :date, nil))

      assert changeset.valid?
    end

    test "accepts nil currency", %{valid_attrs: attrs} do
      changeset = Ticket.changeset(%Ticket{}, Map.put(attrs, :currency, nil))

      assert changeset.valid?
    end

    test "accepts nil total_amount", %{valid_attrs: attrs} do
      changeset = Ticket.changeset(%Ticket{}, Map.put(attrs, :total_amount, nil))

      assert changeset.valid?
    end

    test "accepts nil image_url", %{valid_attrs: attrs} do
      changeset = Ticket.changeset(%Ticket{}, Map.put(attrs, :image_url, nil))

      assert changeset.valid?
    end

    test "rejects negative total_amount", %{valid_attrs: attrs} do
      changeset = Ticket.changeset(%Ticket{}, %{attrs | total_amount: Decimal.new("-10.50")})

      refute changeset.valid?
      assert "must be greater than or equal to 0" in errors_on(changeset).total_amount
    end

    test "accepts zero total_amount", %{valid_attrs: attrs} do
      changeset = Ticket.changeset(%Ticket{}, %{attrs | total_amount: Decimal.new("0")})

      assert changeset.valid?
    end

    test "accepts positive total_amount", %{valid_attrs: attrs} do
      changeset = Ticket.changeset(%Ticket{}, %{attrs | total_amount: Decimal.new("999.99")})

      assert changeset.valid?
    end

    test "accepts various currency codes", %{valid_attrs: attrs} do
      currencies = ["EUR", "USD", "GBP", "JPY", "CHF"]

      for currency <- currencies do
        changeset = Ticket.changeset(%Ticket{}, %{attrs | currency: currency})
        assert changeset.valid?, "Currency #{currency} should be valid"
      end
    end

    test "accepts products_json as map", %{valid_attrs: attrs} do
      products_json = %{
        "products" => [
          %{"name" => "Item 1", "price" => 10.0}
        ]
      }

      changeset = Ticket.changeset(%Ticket{}, Map.put(attrs, :products_json, products_json))

      assert changeset.valid?
    end

    test "sets default total_participants to 0" do
      changeset = Ticket.changeset(%Ticket{}, %{})

      # Default is set in schema
      ticket = %Ticket{}
      assert ticket.total_participants == 0
    end

    test "sets default currency to EUR" do
      ticket = %Ticket{}
      assert ticket.currency == "EUR"
    end
  end

  describe "changeset/2 edge cases" do
    test "accepts minimum valid ticket (only total_participants)" do
      changeset = Ticket.changeset(%Ticket{}, %{total_participants: 1})

      assert changeset.valid?
    end

    test "accepts ticket with all fields populated" do
      changeset =
        Ticket.changeset(%Ticket{}, %{
          total_participants: 5,
          merchant_name: "Full Restaurant",
          date: ~D[2024-12-25],
          currency: "USD",
          total_amount: Decimal.new("543.21"),
          image_url: "https://cdn.example.com/receipt.webp",
          products_json: %{"products" => []}
        })

      assert changeset.valid?
    end
  end
end
