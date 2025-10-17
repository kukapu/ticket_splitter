defmodule TicketSplitter.Tickets do
  @moduledoc """
  The Tickets context.
  """

  import Ecto.Query, warn: false
  alias TicketSplitter.Repo

  alias TicketSplitter.Tickets.{Ticket, Product, ParticipantAssignment}

  ## Ticket functions

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
    |> Repo.preload(products: [:participant_assignments])
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

  ## Product functions

  @doc """
  Returns the list of products for a ticket.
  """
  def list_products_by_ticket(ticket_id) do
    Product
    |> where([p], p.ticket_id == ^ticket_id)
    |> Repo.all()
  end

  @doc """
  Gets a single product.
  """
  def get_product!(id), do: Repo.get!(Product, id)

  @doc """
  Gets a single product with preloaded participant assignments.
  """
  def get_product_with_assignments!(id) do
    Product
    |> Repo.get!(id)
    |> Repo.preload(:participant_assignments)
  end

  @doc """
  Creates a product.
  """
  def create_product(attrs \\ %{}) do
    %Product{}
    |> Product.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a product.
  """
  def update_product(%Product{} = product, attrs) do
    product
    |> Product.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a product.
  """
  def delete_product(%Product{} = product) do
    Repo.delete(product)
  end

  @doc """
  Toggles the is_common flag on a product.
  """
  def toggle_product_common(%Product{} = product) do
    update_product(product, %{is_common: !product.is_common})
  end

  ## ParticipantAssignment functions

  @doc """
  Returns the list of participant assignments for a product.
  """
  def list_assignments_by_product(product_id) do
    ParticipantAssignment
    |> where([pa], pa.product_id == ^product_id)
    |> Repo.all()
  end

  @doc """
  Gets all assignments for a participant across a ticket.
  """
  def get_participant_assignments_by_ticket(ticket_id, participant_name) do
    query =
      from pa in ParticipantAssignment,
        join: p in Product,
        on: pa.product_id == p.id,
        where: p.ticket_id == ^ticket_id and pa.participant_name == ^participant_name,
        preload: [product: p]

    Repo.all(query)
  end

  @doc """
  Gets a single participant assignment.
  """
  def get_participant_assignment!(id), do: Repo.get!(ParticipantAssignment, id)

  @doc """
  Creates a participant assignment.
  """
  def create_participant_assignment(attrs \\ %{}) do
    %ParticipantAssignment{}
    |> ParticipantAssignment.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a participant assignment.
  """
  def update_participant_assignment(%ParticipantAssignment{} = assignment, attrs) do
    assignment
    |> ParticipantAssignment.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a participant assignment.
  """
  def delete_participant_assignment(%ParticipantAssignment{} = assignment) do
    Repo.delete(assignment)
  end

  @doc """
  Assigns a participant to a product with equal percentage distribution.
  If the participant is already assigned, removes the assignment.
  Recalculates percentages for all participants on this product.
  """
  def toggle_participant_assignment(product_id, participant_name, color) do
    existing =
      ParticipantAssignment
      |> where([pa], pa.product_id == ^product_id and pa.participant_name == ^participant_name)
      |> Repo.one()

    result =
      if existing do
        # Remove assignment
        Repo.delete(existing)
      else
        # Add assignment
        create_participant_assignment(%{
          product_id: product_id,
          participant_name: participant_name,
          percentage: Decimal.new("0"),
          assigned_color: color
        })
      end

    case result do
      {:ok, _} ->
        # Recalculate percentages for all participants
        recalculate_percentages(product_id)
        {:ok, :toggled}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Recalculates percentages for all participants assigned to a product.
  Distributes equally among all participants.
  """
  def recalculate_percentages(product_id) do
    assignments = list_assignments_by_product(product_id)
    count = length(assignments)

    if count > 0 do
      percentage = Decimal.div(Decimal.new("100"), Decimal.new(count))

      Enum.each(assignments, fn assignment ->
        update_participant_assignment(assignment, %{percentage: percentage})
      end)
    end

    :ok
  end

  @doc """
  Updates custom percentages for participants on a product.
  Expects a list of {assignment_id, percentage} tuples.
  """
  def update_custom_percentages(updates) do
    Enum.each(updates, fn {assignment_id, percentage} ->
      assignment = get_participant_assignment!(assignment_id)
      update_participant_assignment(assignment, %{percentage: percentage})
    end)

    :ok
  end

  @doc """
  Creates a ticket from OpenRouter JSON response.
  """
  def create_ticket_from_json(products_json, image_url \\ nil) do
    Repo.transaction(fn ->
      # Create ticket
      {:ok, ticket} =
        create_ticket(%{
          image_url: image_url,
          products_json: products_json,
          total_participants: 1
        })

      # Create products from JSON
      products = products_json["products"] || []

      Enum.each(products, fn product_data ->
        create_product(%{
          ticket_id: ticket.id,
          name: product_data["name"],
          units: product_data["units"],
          unit_price: Decimal.new(to_string(product_data["unit_price"])),
          total_price: Decimal.new(to_string(product_data["total_price"])),
          confidence: Decimal.new(to_string(product_data["confidence"] || 0)),
          is_common: false
        })
      end)

      ticket
    end)
  end

  @doc """
  Calculates the total amount a participant owes on a ticket.
  """
  def calculate_participant_total(ticket_id, participant_name) do
    ticket = get_ticket_with_products!(ticket_id)
    total_participants = ticket.total_participants

    ticket.products
    |> Enum.reduce(Decimal.new("0"), fn product, acc ->
      if product.is_common do
        # Divide by total participants
        common_share = Decimal.div(product.total_price, Decimal.new(total_participants))
        Decimal.add(acc, common_share)
      else
        # Find participant's assignment
        assignment =
          Enum.find(product.participant_assignments, fn pa ->
            pa.participant_name == participant_name
          end)

        if assignment do
          # Calculate based on percentage
          share =
            Decimal.mult(product.total_price, Decimal.div(assignment.percentage, Decimal.new("100")))

          Decimal.add(acc, share)
        else
          acc
        end
      end
    end)
  end

  @doc """
  Gets all unique participants for a ticket.
  """
  def get_ticket_participants(ticket_id) do
    query =
      from pa in ParticipantAssignment,
        join: p in Product,
        on: pa.product_id == p.id,
        where: p.ticket_id == ^ticket_id,
        distinct: pa.participant_name,
        select: %{name: pa.participant_name, color: pa.assigned_color}

    Repo.all(query)
  end
end
