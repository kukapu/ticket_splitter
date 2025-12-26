defmodule TicketSplitter.Tickets.Contexts.TicketOperations do
  @moduledoc """
  Operations for Ticket CRUD and creation from external sources.
  """

  import Ecto.Query, warn: false
  alias TicketSplitter.Repo
  alias TicketSplitter.Tickets.{Ticket, Product, TicketCalculator}

  @doc """
  Returns the list of tickets.
  """
  def list_tickets do
    Repo.all(Ticket)
  end

  @doc """
  Gets a single ticket.
  Raises `Ecto.NoResultsError` if the Ticket does not exist.
  """
  def get_ticket!(id), do: Repo.get!(Ticket, id)

  @doc """
  Gets a single ticket with preloaded products and participant assignments.
  Returns {:ok, ticket} if found, {:error, :not_found} otherwise.
  """
  def get_ticket_with_products(id) do
    case Repo.get(Ticket, id) do
      nil ->
        {:error, :not_found}

      ticket ->
        preloaded_ticket =
          ticket
          |> Repo.preload(
            products:
              from(p in Product, order_by: [asc: p.position], preload: [:participant_assignments])
          )

        {:ok, preloaded_ticket}
    end
  end

  @doc """
  Gets a single ticket with preloaded products and participant assignments.
  Raises `Ecto.NoResultsError` if the Ticket does not exist.
  """
  def get_ticket_with_products!(id) do
    Ticket
    |> Repo.get!(id)
    |> Repo.preload(
      products:
        from(p in Product, order_by: [asc: p.position], preload: [:participant_assignments])
    )
  end

  @doc """
  Creates a ticket.
  """
  def create_ticket(attrs \\ %{}) do
    %Ticket{}
    |> Ticket.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a ticket.
  """
  def update_ticket(%Ticket{} = ticket, attrs) do
    ticket
    |> Ticket.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a ticket.
  """
  def delete_ticket(%Ticket{} = ticket) do
    Repo.delete(ticket)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking ticket changes.
  """
  def change_ticket(%Ticket{} = ticket, attrs \\ %{}) do
    Ticket.changeset(ticket, attrs)
  end

  @doc """
  Creates a ticket from JSON products data (from OpenRouter response).
  This function is used to create a ticket after image processing and parsing.
  Uses Ecto.Multi to ensure atomic creation of ticket and all products.
  """
  def create_ticket_from_json(products_json, image_url \\ nil) do
    # Parse date from JSON if present
    ticket_date = TicketCalculator.parse_ticket_date(products_json["date"])

    # Parse total_amount
    total_amount =
      case products_json["total_amount"] do
        nil -> nil
        amount -> Decimal.new(to_string(amount))
      end

    # Build ticket attributes
    ticket_attrs = %{
      image_url: image_url,
      products_json: products_json,
      total_participants: 0,
      merchant_name: products_json["merchant_name"],
      date: ticket_date,
      currency: products_json["currency"] || "EUR",
      total_amount: total_amount
    }

    # Start building Multi transaction
    multi =
      Ecto.Multi.new()
      |> Ecto.Multi.insert(:ticket, Ticket.changeset(%Ticket{}, ticket_attrs))

    # Add product creation steps to Multi
    products = products_json["products"] || []

    multi =
      products
      |> Enum.with_index()
      |> Enum.reduce(multi, fn {product_data, index}, multi_acc ->
        product_attrs = %{
          name: product_data["name"],
          units: product_data["units"],
          unit_price: Decimal.new(to_string(product_data["unit_price"])),
          total_price: Decimal.new(to_string(product_data["total_price"])),
          confidence: Decimal.new(to_string(product_data["confidence"] || 0)),
          is_common: false,
          position: index,
          category: product_data["category"]
        }

        Ecto.Multi.insert(
          multi_acc,
          {:product, index},
          fn %{ticket: ticket} ->
            Product.changeset(%Product{}, Map.put(product_attrs, :ticket_id, ticket.id))
          end
        )
      end)

    # Execute the transaction and return ticket if successful
    case Repo.transaction(multi) do
      {:ok, %{ticket: ticket}} -> {:ok, ticket}
      {:error, :ticket, changeset, _} -> {:error, changeset}
      {:error, {:product, _index}, changeset, _} -> {:error, changeset}
    end
  end
end
