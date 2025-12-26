defmodule TicketSplitter.Tickets.Contexts.TicketOperationsTest do
  use TicketSplitter.DataCase, async: true

  alias TicketSplitter.Tickets
  alias TicketSplitter.Tickets.Contexts.TicketOperations
  alias TicketSplitter.TicketsFixtures

  describe "list_tickets/0" do
    test "returns empty list when no tickets exist" do
      assert TicketOperations.list_tickets() == []
    end

    test "returns all tickets" do
      ticket1 = TicketsFixtures.ticket_fixture()
      ticket2 = TicketsFixtures.ticket_fixture()

      tickets = TicketOperations.list_tickets()

      assert length(tickets) == 2
      ticket_ids = Enum.map(tickets, & &1.id)
      assert ticket1.id in ticket_ids
      assert ticket2.id in ticket_ids
    end
  end

  describe "get_ticket!/1" do
    test "returns ticket when exists" do
      ticket = TicketsFixtures.ticket_fixture()

      retrieved = TicketOperations.get_ticket!(ticket.id)
      assert retrieved.id == ticket.id
    end

    test "raises Ecto.NoResultsError when not found" do
      assert_raise Ecto.NoResultsError, fn ->
        TicketOperations.get_ticket!(Ecto.UUID.generate())
      end
    end
  end

  describe "get_ticket_with_products!/1" do
    test "preloads products and their assignments" do
      ticket = TicketsFixtures.ticket_fixture()
      product = TicketsFixtures.product_fixture(ticket_id: ticket.id)

      TicketsFixtures.participant_assignment_fixture(
        product_id: product.id,
        participant_name: "Alice"
      )

      retrieved = TicketOperations.get_ticket_with_products!(ticket.id)

      assert retrieved.id == ticket.id
      assert length(retrieved.products) == 1
      assert length(hd(retrieved.products).participant_assignments) == 1
    end

    test "returns ticket with empty products list when none exist" do
      ticket = TicketsFixtures.ticket_fixture()

      retrieved = TicketOperations.get_ticket_with_products!(ticket.id)

      assert retrieved.id == ticket.id
      assert retrieved.products == []
    end
  end

  describe "create_ticket/1" do
    test "creates ticket with valid attrs" do
      attrs = %{
        merchant_name: "Test Merchant",
        total_amount: Decimal.new("100.00"),
        date: ~D[2024-01-15],
        image_url: "https://example.com/ticket.jpg",
        total_participants: 2
      }

      assert {:ok, ticket} = TicketOperations.create_ticket(attrs)
      assert ticket.merchant_name == "Test Merchant"
      assert Decimal.equal?(ticket.total_amount, Decimal.new("100.00"))
    end

    test "returns error with invalid attrs" do
      assert {:error, _changeset} =
               TicketOperations.create_ticket(%{total_participants: -1})
    end
  end

  describe "update_ticket/2" do
    test "updates ticket with valid attrs" do
      ticket = TicketsFixtures.ticket_fixture()

      assert {:ok, updated} =
               TicketOperations.update_ticket(ticket, %{merchant_name: "Updated Merchant"})

      assert updated.merchant_name == "Updated Merchant"
    end

    test "returns error with invalid attrs" do
      ticket = TicketsFixtures.ticket_fixture()

      assert {:error, _changeset} =
               TicketOperations.update_ticket(ticket, %{total_participants: -1})
    end
  end

  describe "delete_ticket/1" do
    test "deletes ticket" do
      ticket = TicketsFixtures.ticket_fixture()

      assert {:ok, _deleted} = TicketOperations.delete_ticket(ticket)

      assert_raise Ecto.NoResultsError, fn ->
        TicketOperations.get_ticket!(ticket.id)
      end
    end
  end

  describe "change_ticket/2" do
    test "returns a changeset" do
      ticket = TicketsFixtures.ticket_fixture()
      changeset = TicketOperations.change_ticket(ticket)

      assert %Ecto.Changeset{} = changeset
      assert changeset.data.id == ticket.id
    end
  end

  describe "create_ticket_from_json/2" do
    test "creates ticket with products from valid JSON" do
      products_json = %{
        "merchant_name" => "Test Merchant",
        "date" => "2024-01-15",
        "total_amount" => "100.00",
        "currency" => "EUR",
        "products" => [
          %{
            "name" => "Product 1",
            "units" => 2,
            "unit_price" => "10.00",
            "total_price" => "20.00",
            "confidence" => 0.95
          },
          %{
            "name" => "Product 2",
            "units" => 3,
            "unit_price" => "5.00",
            "total_price" => "15.00",
            "confidence" => 0.90
          }
        ]
      }

      assert {:ok, ticket} = TicketOperations.create_ticket_from_json(products_json)

      ticket = TicketOperations.get_ticket_with_products!(ticket.id)

      assert ticket.merchant_name == "Test Merchant"
      assert ticket.date == ~D[2024-01-15]
      assert Decimal.equal?(ticket.total_amount, Decimal.new("100.00"))
      assert ticket.currency == "EUR"
      assert length(ticket.products) == 2
    end

    test "handles merchant_name, date, total correctly" do
      products_json = %{
        "merchant_name" => "Supermarket",
        "date" => "2024-03-20",
        "total_amount" => "250.50",
        "products" => []
      }

      assert {:ok, ticket} = TicketOperations.create_ticket_from_json(products_json)

      assert ticket.merchant_name == "Supermarket"
      assert ticket.date == ~D[2024-03-20]
      assert Decimal.equal?(ticket.total_amount, Decimal.new("250.50"))
    end

    test "creates products with correct structure" do
      products_json = %{
        "merchant_name" => "Test",
        "products" => [
          %{
            "name" => "Milk",
            "units" => 1,
            "unit_price" => "2.50",
            "total_price" => "2.50",
            "confidence" => 0.98
          }
        ]
      }

      assert {:ok, ticket} = TicketOperations.create_ticket_from_json(products_json)

      ticket = TicketOperations.get_ticket_with_products!(ticket.id)

      assert length(ticket.products) == 1
      product = hd(ticket.products)

      assert product.name == "Milk"
      assert product.units == 1
      assert Decimal.equal?(product.unit_price, Decimal.new("2.50"))
      assert Decimal.equal?(product.total_price, Decimal.new("2.50"))
      assert Decimal.equal?(product.confidence, Decimal.new("0.98"))
      assert product.is_common == false
    end

    test "associates image_url correctly" do
      products_json = %{
        "merchant_name" => "Test",
        "products" => []
      }

      image_url = "https://example.com/ticket123.jpg"

      assert {:ok, ticket} = TicketOperations.create_ticket_from_json(products_json, image_url)

      assert ticket.image_url == image_url
    end

    test "handles category field in products" do
      products_json = %{
        "merchant_name" => "Test",
        "products" => [
          %{
            "name" => "Bread",
            "units" => 1,
            "unit_price" => "1.00",
            "total_price" => "1.00",
            "category" => "MAIN"
          }
        ]
      }

      assert {:ok, ticket} = TicketOperations.create_ticket_from_json(products_json)

      ticket = TicketOperations.get_ticket_with_products!(ticket.id)
      product = hd(ticket.products)
      assert product.category == "MAIN"
    end

    test "handles nil date in JSON" do
      products_json = %{
        "merchant_name" => "Test",
        "date" => nil,
        "products" => []
      }

      assert {:ok, ticket} = TicketOperations.create_ticket_from_json(products_json)

      assert ticket.date == nil
    end

    test "handles nil total_amount in JSON" do
      products_json = %{
        "merchant_name" => "Test",
        "total_amount" => nil,
        "products" => []
      }

      assert {:ok, ticket} = TicketOperations.create_ticket_from_json(products_json)

      assert ticket.total_amount == nil
    end

    test "assigns correct position to products" do
      products_json = %{
        "merchant_name" => "Test",
        "products" => [
          %{
            "name" => "Product 1",
            "units" => 1,
            "unit_price" => "1.00",
            "total_price" => "1.00"
          },
          %{
            "name" => "Product 2",
            "units" => 1,
            "unit_price" => "2.00",
            "total_price" => "2.00"
          },
          %{
            "name" => "Product 3",
            "units" => 1,
            "unit_price" => "3.00",
            "total_price" => "3.00"
          }
        ]
      }

      assert {:ok, ticket} = TicketOperations.create_ticket_from_json(products_json)

      ticket = TicketOperations.get_ticket_with_products!(ticket.id)
      positions = Enum.map(ticket.products, & &1.position)
      assert positions == [0, 1, 2]
    end

    test "returns ticket within transaction" do
      products_json = %{
        "merchant_name" => "Test",
        "products" => [
          %{
            "name" => "Product 1",
            "units" => 1,
            "unit_price" => "1.00",
            "total_price" => "1.00"
          }
        ]
      }

      result = TicketOperations.create_ticket_from_json(products_json)

      assert {:ok, ticket} = result
      assert is_struct(ticket, Tickets.Ticket)
    end
  end

  describe "create_ticket_from_json/2 - transaction behavior" do
    test "successfully creates ticket and all products" do
      initial_ticket_count = Repo.aggregate(Tickets.Ticket, :count)
      initial_product_count = Repo.aggregate(Tickets.Product, :count)

      products_json = %{
        "merchant_name" => "Valid Merchant",
        "products" => [
          %{"name" => "P1", "units" => 1, "unit_price" => "1.00", "total_price" => "1.00"},
          %{"name" => "P2", "units" => 2, "unit_price" => "2.00", "total_price" => "4.00"},
          %{"name" => "P3", "units" => 3, "unit_price" => "3.00", "total_price" => "9.00"}
        ]
      }

      assert {:ok, ticket} = TicketOperations.create_ticket_from_json(products_json)

      # Verify counts increased correctly
      assert Repo.aggregate(Tickets.Ticket, :count) == initial_ticket_count + 1
      assert Repo.aggregate(Tickets.Product, :count) == initial_product_count + 3

      # Verify products are associated with ticket
      products = TicketOperations.get_ticket_with_products!(ticket.id).products
      assert length(products) == 3
    end

    test "rolls back entire transaction when product has invalid category" do
      initial_ticket_count = Repo.aggregate(Tickets.Ticket, :count)
      initial_product_count = Repo.aggregate(Tickets.Product, :count)

      # products_json with invalid category
      products_json = %{
        "merchant_name" => "Test Merchant",
        "products" => [
          %{
            "name" => "Valid Name",
            "units" => 1,
            "unit_price" => "5.00",
            "total_price" => "5.00",
            "category" => "INVALID_CATEGORY"
          }
        ]
      }

      # Should fail entire transaction due to invalid product
      result = TicketOperations.create_ticket_from_json(products_json)

      assert {:error, changeset} = result
      assert "is invalid" in errors_on(changeset).category

      # Neither ticket nor product should be created (transaction rollback)
      assert Repo.aggregate(Tickets.Ticket, :count) == initial_ticket_count
      assert Repo.aggregate(Tickets.Product, :count) == initial_product_count
    end

    test "maintains data integrity of existing tickets" do
      # Create an existing ticket to ensure isolation
      existing_ticket = TicketsFixtures.ticket_fixture()
      TicketsFixtures.product_fixture(ticket_id: existing_ticket.id)

      initial_existing_products =
        Tickets.list_products_by_ticket(existing_ticket.id) |> length()

      # Try to create a new ticket (even if it fails, existing data should be intact)
      _result =
        TicketOperations.create_ticket_from_json(%{
          "merchant_name" => "New Merchant",
          "products" => []
        })

      # Verify existing ticket was not affected
      existing_products = Tickets.list_products_by_ticket(existing_ticket.id) |> length()
      assert existing_products == initial_existing_products
    end
  end
end
