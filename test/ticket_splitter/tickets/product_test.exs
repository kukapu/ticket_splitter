defmodule TicketSplitter.Tickets.ProductTest do
  use TicketSplitter.DataCase, async: true

  alias TicketSplitter.Tickets.Product
  import TicketSplitter.TicketsFixtures

  describe "changeset/2 validations" do
    setup do
      ticket = ticket_fixture()

      valid_attrs = %{
        ticket_id: ticket.id,
        name: "Test Product",
        units: 5,
        unit_price: Decimal.new("10.50"),
        total_price: Decimal.new("52.50")
      }

      %{valid_attrs: valid_attrs, ticket: ticket}
    end

    test "accepts valid attributes", %{valid_attrs: attrs} do
      changeset = Product.changeset(%Product{}, attrs)

      assert changeset.valid?
    end

    test "requires ticket_id", %{valid_attrs: attrs} do
      changeset = Product.changeset(%Product{}, Map.delete(attrs, :ticket_id))

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).ticket_id
    end

    test "requires name", %{valid_attrs: attrs} do
      changeset = Product.changeset(%Product{}, Map.delete(attrs, :name))

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).name
    end

    test "requires units", %{valid_attrs: attrs} do
      changeset = Product.changeset(%Product{}, Map.delete(attrs, :units))

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).units
    end

    test "requires unit_price", %{valid_attrs: attrs} do
      changeset = Product.changeset(%Product{}, Map.delete(attrs, :unit_price))

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).unit_price
    end

    test "requires total_price", %{valid_attrs: attrs} do
      changeset = Product.changeset(%Product{}, Map.delete(attrs, :total_price))

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).total_price
    end

    test "rejects units equal to 0", %{valid_attrs: attrs} do
      changeset = Product.changeset(%Product{}, %{attrs | units: 0})

      refute changeset.valid?
      assert "must be greater than 0" in errors_on(changeset).units
    end

    test "rejects negative units", %{valid_attrs: attrs} do
      changeset = Product.changeset(%Product{}, %{attrs | units: -5})

      refute changeset.valid?
      assert "must be greater than 0" in errors_on(changeset).units
    end

    test "rejects negative unit_price", %{valid_attrs: attrs} do
      changeset = Product.changeset(%Product{}, %{attrs | unit_price: Decimal.new("-5.00")})

      refute changeset.valid?
      assert "must be greater than or equal to 0" in errors_on(changeset).unit_price
    end

    test "accepts zero unit_price", %{valid_attrs: attrs} do
      changeset = Product.changeset(%Product{}, %{attrs | unit_price: Decimal.new("0")})

      assert changeset.valid?
    end

    test "rejects negative total_price", %{valid_attrs: attrs} do
      changeset = Product.changeset(%Product{}, %{attrs | total_price: Decimal.new("-10.00")})

      refute changeset.valid?
      assert "must be greater than or equal to 0" in errors_on(changeset).total_price
    end

    test "accepts zero total_price", %{valid_attrs: attrs} do
      changeset = Product.changeset(%Product{}, %{attrs | total_price: Decimal.new("0")})

      assert changeset.valid?
    end

    test "accepts valid category DRINK", %{valid_attrs: attrs} do
      changeset = Product.changeset(%Product{}, Map.put(attrs, :category, "DRINK"))

      assert changeset.valid?
    end

    test "accepts valid category STARTER", %{valid_attrs: attrs} do
      changeset = Product.changeset(%Product{}, Map.put(attrs, :category, "STARTER"))

      assert changeset.valid?
    end

    test "accepts valid category MAIN", %{valid_attrs: attrs} do
      changeset = Product.changeset(%Product{}, Map.put(attrs, :category, "MAIN"))

      assert changeset.valid?
    end

    test "accepts valid category DESSERT", %{valid_attrs: attrs} do
      changeset = Product.changeset(%Product{}, Map.put(attrs, :category, "DESSERT"))

      assert changeset.valid?
    end

    test "accepts valid category OTHER", %{valid_attrs: attrs} do
      changeset = Product.changeset(%Product{}, Map.put(attrs, :category, "OTHER"))

      assert changeset.valid?
    end

    test "rejects invalid category", %{valid_attrs: attrs} do
      changeset = Product.changeset(%Product{}, Map.put(attrs, :category, "INVALID"))

      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).category
    end

    test "accepts nil category", %{valid_attrs: attrs} do
      changeset = Product.changeset(%Product{}, Map.put(attrs, :category, nil))

      assert changeset.valid?
    end

    test "validates foreign_key_constraint on invalid ticket_id" do
      invalid_attrs = %{
        ticket_id: Ecto.UUID.generate(),
        name: "Test",
        units: 1,
        unit_price: Decimal.new("1.00"),
        total_price: Decimal.new("1.00")
      }

      {:error, changeset} =
        %Product{}
        |> Product.changeset(invalid_attrs)
        |> Repo.insert()

      assert "does not exist" in errors_on(changeset).ticket_id
    end

    test "sets default values correctly" do
      ticket = ticket_fixture()

      {:ok, product} =
        %Product{}
        |> Product.changeset(%{
          ticket_id: ticket.id,
          name: "Test",
          units: 1,
          unit_price: Decimal.new("1.00"),
          total_price: Decimal.new("1.00")
        })
        |> Repo.insert()

      # Reload from DB to get the actual stored values
      product = Repo.get!(Product, product.id)

      # Verify defaults were applied
      assert product.is_common == false
      # common_units should be 0 (either as Decimal or converted from float)
      assert Decimal.compare(product.common_units, 0) == :eq
      assert product.position == 0
    end
  end
end
