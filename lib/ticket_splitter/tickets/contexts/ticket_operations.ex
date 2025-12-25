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
  """
  def create_ticket_from_json(products_json, image_url \\ nil) do
    Repo.transaction(fn ->
      # Parse date from JSON if present
      ticket_date = TicketCalculator.parse_ticket_date(products_json["date"])

      # Parse total_amount
      total_amount =
        case products_json["total_amount"] do
          nil -> nil
          amount -> Decimal.new(to_string(amount))
        end

      # Create ticket with new merchant info
      {:ok, ticket} =
        create_ticket(%{
          image_url: image_url,
          products_json: products_json,
          total_participants: 1,
          merchant_name: products_json["merchant_name"],
          date: ticket_date,
          currency: products_json["currency"] || "EUR",
          total_amount: total_amount
        })

      # Create products from JSON
      products = products_json["products"] || []

      # Need to delegate to ProductOperations for create_product
      # For now, we'll use the context directly
      Enum.with_index(products, fn product_data, index ->
        TicketSplitter.Tickets.create_product(%{
          ticket_id: ticket.id,
          name: product_data["name"],
          units: product_data["units"],
          unit_price: Decimal.new(to_string(product_data["unit_price"])),
          total_price: Decimal.new(to_string(product_data["total_price"])),
          confidence: Decimal.new(to_string(product_data["confidence"] || 0)),
          is_common: false,
          position: index,
          category: product_data["category"]
        })
      end)

      ticket
    end)
  end
end
