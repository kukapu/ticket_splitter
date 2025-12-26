defmodule TicketSplitter.Tickets.Contexts.ProductOperationsTest do
  use TicketSplitter.DataCase, async: true

  alias TicketSplitter.Tickets
  alias TicketSplitter.Tickets.Contexts.ProductOperations
  alias TicketSplitter.TicketsFixtures

  describe "list_products_by_ticket/1" do
    test "returns empty list when no products exist" do
      ticket = TicketsFixtures.ticket_fixture()
      assert ProductOperations.list_products_by_ticket(ticket.id) == []
    end

    test "returns all products for a ticket" do
      ticket = TicketsFixtures.ticket_fixture()
      product1 = TicketsFixtures.product_fixture(ticket_id: ticket.id)
      product2 = TicketsFixtures.product_fixture(ticket_id: ticket.id)

      products = ProductOperations.list_products_by_ticket(ticket.id)

      assert length(products) == 2
      product_ids = Enum.map(products, & &1.id)
      assert product1.id in product_ids
      assert product2.id in product_ids
    end

    test "does not return products from other tickets" do
      ticket1 = TicketsFixtures.ticket_fixture()
      ticket2 = TicketsFixtures.ticket_fixture()

      TicketsFixtures.product_fixture(ticket_id: ticket1.id)
      TicketsFixtures.product_fixture(ticket_id: ticket2.id)

      products = ProductOperations.list_products_by_ticket(ticket1.id)

      assert length(products) == 1
    end
  end

  describe "get_product!/1" do
    test "returns product when exists" do
      product = TicketsFixtures.product_fixture()

      retrieved = ProductOperations.get_product!(product.id)
      assert retrieved.id == product.id
    end

    test "raises Ecto.NoResultsError when not found" do
      assert_raise Ecto.NoResultsError, fn ->
        ProductOperations.get_product!(Ecto.UUID.generate())
      end
    end
  end

  describe "get_product_with_assignments!/1" do
    test "returns product with preloaded assignments" do
      product = TicketsFixtures.product_fixture()

      TicketsFixtures.participant_assignment_fixture(
        product_id: product.id,
        participant_name: "Alice"
      )

      TicketsFixtures.participant_assignment_fixture(
        product_id: product.id,
        participant_name: "Bob"
      )

      retrieved = ProductOperations.get_product_with_assignments!(product.id)

      assert retrieved.id == product.id
      assert length(retrieved.participant_assignments) == 2
    end

    test "returns product with empty assignments when none exist" do
      product = TicketsFixtures.product_fixture()

      retrieved = ProductOperations.get_product_with_assignments!(product.id)

      assert retrieved.id == product.id
      assert retrieved.participant_assignments == []
    end
  end

  describe "create_product/1" do
    test "creates product with valid attrs" do
      ticket = TicketsFixtures.ticket_fixture()

      attrs = %{
        ticket_id: ticket.id,
        name: "Test Product",
        total_price: Decimal.new("10.00"),
        unit_price: Decimal.new("1.00"),
        units: 10,
        is_common: false
      }

      assert {:ok, product} = ProductOperations.create_product(attrs)
      assert product.ticket_id == ticket.id
      assert product.name == "Test Product"
      assert Decimal.equal?(product.total_price, Decimal.new("10.00"))
    end

    test "returns error with invalid attrs" do
      assert {:error, _changeset} = ProductOperations.create_product(%{ticket_id: nil})
    end
  end

  describe "update_product/2" do
    test "updates product with valid attrs" do
      product = TicketsFixtures.product_fixture()

      assert {:ok, updated} =
               ProductOperations.update_product(product, %{name: "Updated Product"})

      assert updated.name == "Updated Product"
    end

    test "returns error with invalid attrs" do
      product = TicketsFixtures.product_fixture()

      assert {:error, _changeset} =
               ProductOperations.update_product(product, %{units: -1})
    end
  end

  describe "delete_product/1" do
    test "deletes product" do
      product = TicketsFixtures.product_fixture()

      assert {:ok, _deleted} = ProductOperations.delete_product(product)

      assert_raise Ecto.NoResultsError, fn ->
        ProductOperations.get_product!(product.id)
      end
    end
  end

  describe "toggle_product_common/1" do
    test "sets is_common to true when false" do
      product = TicketsFixtures.product_fixture(is_common: false)

      assert {:ok, updated} = ProductOperations.toggle_product_common(product)
      assert updated.is_common == true
    end

    test "sets is_common to false when true" do
      product = TicketsFixtures.product_fixture(is_common: true)

      assert {:ok, updated} = ProductOperations.toggle_product_common(product)
      assert updated.is_common == false
    end
  end

  describe "make_product_common/1" do
    test "sets is_common to true when product has no assignments" do
      product = TicketsFixtures.product_fixture(is_common: false)

      assert {:ok, updated} = ProductOperations.make_product_common(product)
      assert updated.is_common == true
    end

    test "returns error when product has assignments" do
      product = TicketsFixtures.product_fixture(is_common: false)

      TicketsFixtures.participant_assignment_fixture(product_id: product.id)

      assert {:error, :has_assignments} = ProductOperations.make_product_common(product)
    end

    test "does not change is_common when already true" do
      product = TicketsFixtures.product_fixture(is_common: true)

      assert {:ok, updated} = ProductOperations.make_product_common(product)
      assert updated.is_common == true
    end
  end

  describe "make_product_not_common/1" do
    test "sets is_common to false" do
      product = TicketsFixtures.product_fixture(is_common: true)

      assert {:ok, updated} = ProductOperations.make_product_not_common(product)
      assert updated.is_common == false
    end
  end

  describe "add_common_units/2" do
    setup do
      product = TicketsFixtures.product_fixture(units: 10, common_units: Decimal.new("0"))
      %{product: product}
    end

    test "adds common units within available range", %{product: product} do
      assert {:ok, updated} = ProductOperations.add_common_units(product.id, 5)

      assert Decimal.equal?(updated.common_units, Decimal.new("5"))
    end

    test "adds single unit when not specified", %{product: product} do
      assert {:ok, updated} = ProductOperations.add_common_units(product.id)

      assert Decimal.equal?(updated.common_units, Decimal.new("1"))
    end

    test "returns error when trying to exceed total units", %{product: product} do
      assert {:error, :not_enough_units} = ProductOperations.add_common_units(product.id, 15)
    end

    test "updates common_units field correctly", %{product: product} do
      assert {:ok, updated} = ProductOperations.add_common_units(product.id, 3)

      assert Decimal.equal?(updated.common_units, Decimal.new("3"))

      assert {:ok, updated2} = ProductOperations.add_common_units(product.id, 2)

      assert Decimal.equal?(updated2.common_units, Decimal.new("5"))
    end

    test "works with Decimal units correctly", %{product: product} do
      assert {:ok, updated} = ProductOperations.add_common_units(product.id, 3)

      assert Decimal.equal?(updated.common_units, Decimal.new("3"))

      assert is_struct(updated.common_units, Decimal)
    end

    test "respects assigned units when checking availability", %{product: product} do
      TicketsFixtures.participant_assignment_fixture(
        product_id: product.id,
        units_assigned: Decimal.new("5")
      )

      assert {:ok, updated} = ProductOperations.add_common_units(product.id, 3)

      assert Decimal.equal?(updated.common_units, Decimal.new("3"))

      assert {:error, :not_enough_units} = ProductOperations.add_common_units(product.id, 3)
    end

    test "respects existing common_units", %{product: product} do
      {:ok, product} =
        TicketSplitter.Tickets.update_product(product, %{common_units: Decimal.new("2")})

      assert {:ok, updated} = ProductOperations.add_common_units(product.id, 3)

      assert Decimal.equal?(updated.common_units, Decimal.new("5"))
    end
  end

  describe "remove_common_units/2" do
    setup do
      product =
        TicketsFixtures.product_fixture(
          units: 10,
          common_units: Decimal.new("5")
        )

      %{product: product}
    end

    test "removes common units when available", %{product: product} do
      assert {:ok, updated} = ProductOperations.remove_common_units(product.id, 2)

      assert Decimal.equal?(updated.common_units, Decimal.new("3"))
    end

    test "removes single unit when not specified", %{product: product} do
      assert {:ok, updated} = ProductOperations.remove_common_units(product.id)

      assert Decimal.equal?(updated.common_units, Decimal.new("4"))
    end

    test "returns error when not enough common units", %{product: product} do
      assert {:error, :not_enough_common_units} =
               ProductOperations.remove_common_units(product.id, 10)
    end

    test "updates common_units field correctly", %{product: product} do
      assert {:ok, updated} = ProductOperations.remove_common_units(product.id, 2)

      assert Decimal.equal?(updated.common_units, Decimal.new("3"))

      assert {:ok, updated2} = ProductOperations.remove_common_units(product.id, 1)

      assert Decimal.equal?(updated2.common_units, Decimal.new("2"))
    end
  end

  describe "get_available_units/1" do
    test "calculates available units = total - assigned - common" do
      product = TicketsFixtures.product_fixture(units: 10)

      TicketsFixtures.participant_assignment_fixture(
        product_id: product.id,
        units_assigned: Decimal.new("3")
      )

      {:ok, product} =
        TicketSplitter.Tickets.update_product(product, %{common_units: Decimal.new("2")})

      available = ProductOperations.get_available_units(product.id)

      assert Decimal.equal?(available, Decimal.new("5"))
    end

    test "handles product with no assignments" do
      product = TicketsFixtures.product_fixture(units: 10)

      available = ProductOperations.get_available_units(product.id)

      assert Decimal.equal?(available, Decimal.new("10"))
    end

    test "handles product with all units assigned" do
      product = TicketsFixtures.product_fixture(units: 10)

      TicketsFixtures.participant_assignment_fixture(
        product_id: product.id,
        units_assigned: Decimal.new("10")
      )

      available = ProductOperations.get_available_units(product.id)

      assert Decimal.equal?(available, Decimal.new("0"))
    end

    test "handles product with all units common" do
      product = TicketsFixtures.product_fixture(units: 10)

      {:ok, product} =
        TicketSplitter.Tickets.update_product(product, %{common_units: Decimal.new("10")})

      available = ProductOperations.get_available_units(product.id)

      assert Decimal.equal?(available, Decimal.new("0"))
    end

    test "handles product with assigned and common units" do
      product = TicketsFixtures.product_fixture(units: 10)

      TicketsFixtures.participant_assignment_fixture(
        product_id: product.id,
        units_assigned: Decimal.new("4")
      )

      {:ok, product} =
        TicketSplitter.Tickets.update_product(product, %{common_units: Decimal.new("3")})

      available = ProductOperations.get_available_units(product.id)

      assert Decimal.equal?(available, Decimal.new("3"))
    end

    test "returns Decimal type" do
      product = TicketsFixtures.product_fixture(units: 10)

      available = ProductOperations.get_available_units(product.id)

      assert is_struct(available, Decimal)
    end

    test "handles shared groups correctly (counts group once)" do
      product = TicketsFixtures.product_fixture(units: 10)
      group_id = Ecto.UUID.generate()

      for name <- ["Alice", "Bob", "Charlie"] do
        TicketsFixtures.participant_assignment_fixture(
          product_id: product.id,
          participant_name: name,
          units_assigned: Decimal.new("3"),
          assignment_group_id: group_id
        )
      end

      available = ProductOperations.get_available_units(product.id)

      assert Decimal.equal?(available, Decimal.new("7"))
    end
  end

end
