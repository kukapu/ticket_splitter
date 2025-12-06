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

  @doc """
  Makes a product common if it has no assignments.
  Returns error if product already has participant assignments.
  """
  def make_product_common(%Product{} = product) do
    assignments = list_assignments_by_product(product.id)

    if length(assignments) == 0 do
      update_product(product, %{is_common: true})
    else
      {:error, :has_assignments}
    end
  end

  @doc """
  Makes a product not common (removes from common status).
  """
  def make_product_not_common(%Product{} = product) do
    update_product(product, %{is_common: false})
  end

  @doc """
  Adds units to the common pool for a product.
  """
  def add_common_units(product_id, units_to_add \\ 1) do
    IO.puts("🟢 add_common_units called: product_id=#{product_id}, units_to_add=#{units_to_add}")
    product = get_product!(product_id)

    # Calculate available units
    total_assigned = get_total_assigned_units(product_id)
    current_common = product.common_units || Decimal.new("0")

    available =
      Decimal.sub(Decimal.new(product.units), Decimal.add(total_assigned, current_common))

    IO.puts(
      "  Available: #{available}, Current common: #{current_common}, Total assigned: #{total_assigned}"
    )

    units_decimal = Decimal.new(units_to_add)

    # Check if enough available
    result =
      if Decimal.compare(available, units_decimal) in [:gt, :eq] do
        new_common = Decimal.add(current_common, units_decimal)
        IO.puts("  ✅ Adding units. New common: #{new_common}")
        update_product(product, %{common_units: new_common})
      else
        IO.puts("  ❌ Not enough units available")
        {:error, :not_enough_units}
      end

    IO.inspect(result, label: "  Result")
    result
  end

  @doc """
  Removes units from the common pool for a product.
  """
  def remove_common_units(product_id, units_to_remove \\ 1) do
    product = get_product!(product_id)
    current_common = product.common_units || Decimal.new("0")
    units_decimal = Decimal.new(units_to_remove)

    if Decimal.compare(current_common, units_decimal) in [:gt, :eq] do
      new_common = Decimal.sub(current_common, units_decimal)
      update_product(product, %{common_units: new_common})
    else
      {:error, :not_enough_common_units}
    end
  end

  @doc """
  Gets available (unassigned and non-common) units for a product.
  """
  def get_available_units(product_id) do
    product = get_product!(product_id)
    total_assigned = get_total_assigned_units(product_id)
    common_units = product.common_units || Decimal.new("0")

    Decimal.new(product.units)
    |> Decimal.sub(total_assigned)
    |> Decimal.sub(common_units)
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
    # Normalize name to lowercase for case-insensitive comparison
    participant_name = String.downcase(String.trim(participant_name))

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
  Adds one unit from the pool to a participant.
  Creates a new assignment group.
  """
  def add_participant_unit(product_id, participant_name, color) do
    # Normalize name to lowercase for case-insensitive comparison
    participant_name = String.downcase(String.trim(participant_name))

    # Calculate available units (excluding assigned AND common units)
    available = get_available_units(product_id)

    # Check if there are available units
    if Decimal.compare(available, Decimal.new("1")) in [:gt, :eq] do
      # Check if participant has a solo (unshared) assignment
      existing_solo =
        ParticipantAssignment
        |> where([pa], pa.product_id == ^product_id and pa.participant_name == ^participant_name)
        |> Repo.all()
        |> Enum.find(fn pa ->
          # Solo assignment: either no group_id or is the only one in the group
          if pa.assignment_group_id do
            group_count =
              ParticipantAssignment
              |> where([pa2], pa2.assignment_group_id == ^pa.assignment_group_id)
              |> Repo.aggregate(:count)

            group_count == 1
          else
            true
          end
        end)

      if existing_solo do
        # Add one more unit to existing solo assignment
        current_units = existing_solo.units_assigned || Decimal.new("0")
        new_units = Decimal.add(current_units, Decimal.new("1"))
        update_participant_assignment(existing_solo, %{units_assigned: new_units})
      else
        # Create new assignment with 1 unit and new group
        group_id = Ecto.UUID.generate()

        create_participant_assignment(%{
          product_id: product_id,
          participant_name: participant_name,
          units_assigned: Decimal.new("1"),
          percentage: Decimal.new("100"),
          assigned_color: color,
          assignment_group_id: group_id
        })
      end
    else
      {:error, :no_units_available}
    end
  end

  @doc """
  Joins an existing assignment group (shares units with others).
  """
  def join_assignment_group(assignment_group_id, participant_name, color) do
    # Normalize name to lowercase for case-insensitive comparison
    participant_name = String.downcase(String.trim(participant_name))

    # Get existing assignments in this group
    group_assignments =
      ParticipantAssignment
      |> where([pa], pa.assignment_group_id == ^assignment_group_id)
      |> Repo.all()

    if length(group_assignments) == 0 do
      {:error, :group_not_found}
    else
      # Check if participant is already in this group
      already_in_group =
        Enum.any?(group_assignments, fn pa -> pa.participant_name == participant_name end)

      if already_in_group do
        {:error, :already_in_group}
      else
        # Get units_assigned from the group (they all share the same units)
        units = hd(group_assignments).units_assigned || Decimal.new("0")
        product_id = hd(group_assignments).product_id

        # Create new assignment in the same group
        result =
          create_participant_assignment(%{
            product_id: product_id,
            participant_name: participant_name,
            units_assigned: units,
            percentage: Decimal.new("0"),
            assigned_color: color,
            assignment_group_id: assignment_group_id
          })

        case result do
          {:ok, _} ->
            # Recalculate percentages for all in the group
            recalculate_group_percentages(assignment_group_id)
            {:ok, :joined}

          error ->
            error
        end
      end
    end
  end

  @doc """
  Removes a participant from an assignment group.
  If it's the last participant, removes the group entirely.
  """
  def remove_from_assignment_group(assignment_group_id, participant_name) do
    # Normalize name to lowercase for case-insensitive comparison
    participant_name = String.downcase(String.trim(participant_name))

    # Get participant's assignment in this group
    assignment =
      ParticipantAssignment
      |> where(
        [pa],
        pa.assignment_group_id == ^assignment_group_id and
          pa.participant_name == ^participant_name
      )
      |> Repo.one()

    if assignment do
      # Delete this participant's assignment
      Repo.delete(assignment)

      # Check how many are left in the group
      remaining =
        ParticipantAssignment
        |> where([pa], pa.assignment_group_id == ^assignment_group_id)
        |> Repo.all()

      if length(remaining) > 0 do
        # Recalculate percentages for remaining participants
        recalculate_group_percentages(assignment_group_id)
      end

      {:ok, :removed}
    else
      {:error, :not_in_group}
    end
  end

  @doc """
  Removes one unit from a participant.
  If solo and has multiple units: subtract 1
  If solo and has 1 unit: remove assignment
  If shared: leave the group
  """
  def remove_participant_unit(product_id, participant_name, target_group_id \\ nil) do
    # Normalize name to lowercase for case-insensitive comparison
    participant_name = String.downcase(String.trim(participant_name))

    # Find participant's assignments for this product
    assignments =
      ParticipantAssignment
      |> where([pa], pa.product_id == ^product_id and pa.participant_name == ^participant_name)
      |> Repo.all()

    if length(assignments) == 0 do
      {:error, :no_assignment}
    else
      assignment =
        if target_group_id do
          # Try to find the specific assignment for this group
          Enum.find(assignments, fn pa -> pa.assignment_group_id == target_group_id end)
        else
          # Fallback to smart prioritization
          # Sort assignments to prioritize solo ones (group_count == 1 OR no group)
          sorted_assignments =
            Enum.sort_by(assignments, fn pa ->
              if pa.assignment_group_id do
                group_count =
                  ParticipantAssignment
                  |> where([pa2], pa2.assignment_group_id == ^pa.assignment_group_id)
                  |> Repo.aggregate(:count)

                # If count is 1, it's effectively solo (priority 0)
                # If count > 1, it's shared (priority 1)
                if group_count == 1, do: 0, else: 1
              else
                # No group is legacy solo (priority 0)
                0
              end
            end)

          hd(sorted_assignments)
        end

      # If for some reason target_group_id was not valid/found, we might have nil assignment
      if is_nil(assignment) do
        {:error, :assignment_not_found}
      else
        # Proceed with removal logic for the selected assignment

        # Check if it's shared
        if assignment.assignment_group_id do
          group_count =
            ParticipantAssignment
            |> where([pa], pa.assignment_group_id == ^assignment.assignment_group_id)
            |> Repo.aggregate(:count)

          if group_count > 1 do
            # It's shared - remove from group
            remove_from_assignment_group(assignment.assignment_group_id, participant_name)
          else
            # Solo - check units
            current_units = assignment.units_assigned || Decimal.new("0")

            if Decimal.compare(current_units, Decimal.new("1")) == :eq do
              # Only 1 unit - remove completely
              Repo.delete(assignment)
            else
              # More than 1 unit - subtract one
              new_units = Decimal.sub(current_units, Decimal.new("1"))
              update_participant_assignment(assignment, %{units_assigned: new_units})
            end
          end
        else
          # No group (old data) - treat as solo
          current_units = assignment.units_assigned || Decimal.new("0")

          if Decimal.compare(current_units, Decimal.new("1")) == :eq do
            Repo.delete(assignment)
          else
            new_units = Decimal.sub(current_units, Decimal.new("1"))
            update_participant_assignment(assignment, %{units_assigned: new_units})
          end
        end
      end
    end
  end

  @doc """
  Recalculates percentages for all participants in an assignment group.
  Distributes equally.
  """
  def recalculate_group_percentages(assignment_group_id) do
    assignments =
      ParticipantAssignment
      |> where([pa], pa.assignment_group_id == ^assignment_group_id)
      |> Repo.all()

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
  Gets total units assigned to all participants for a product.
  Groups are counted only once (not per participant).
  """
  def get_total_assigned_units(product_id) do
    ParticipantAssignment
    |> where([pa], pa.product_id == ^product_id)
    |> Repo.all()
    |> Enum.group_by(fn pa -> pa.assignment_group_id end)
    |> Enum.reduce(Decimal.new("0"), fn {_group_id, assignments}, acc ->
      # All assignments in a group share the same units, so just take the first one
      units = hd(assignments).units_assigned || Decimal.new("0")
      Decimal.add(acc, units)
    end)
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
  Updates split percentages for a 2-person group.
  Used by the interactive divider feature.
  """
  def update_split_percentages(group_id, participant1_percentage, participant2_percentage) do
    # Get all assignments in this group, ordered by participant name for consistency
    assignments =
      ParticipantAssignment
      |> where([pa], pa.assignment_group_id == ^group_id)
      |> order_by([pa], asc: pa.participant_name)
      |> Repo.all()

    if length(assignments) == 2 do
      # Convert percentages to decimals
      p1_decimal = Decimal.new(to_string(participant1_percentage))
      p2_decimal = Decimal.new(to_string(participant2_percentage))

      # Update each assignment based on order (alphabetical by participant name)
      assignments
      |> Enum.with_index()
      |> Enum.each(fn {assignment, index} ->
        new_percentage =
          if index == 0 do
            # First assignment (alphabetically) gets participant1_percentage
            p1_decimal
          else
            # Second assignment gets participant2_percentage
            p2_decimal
          end

        update_participant_assignment(assignment, %{percentage: new_percentage})
      end)

      :ok
    else
      {:error, :invalid_group_size}
    end
  end

  @doc """
  Creates a ticket from OpenRouter JSON response.
  """
  def create_ticket_from_json(products_json, image_url \\ nil) do
    Repo.transaction(fn ->
      # Parse date from JSON if present
      ticket_date = parse_ticket_date(products_json["date"])

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

      Enum.with_index(products, fn product_data, index ->
        create_product(%{
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

  # Parses date from JSON format (YYYY-MM-DD string) to Date
  defp parse_ticket_date(nil), do: nil

  defp parse_ticket_date(date_string) when is_binary(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> date
      {:error, _} -> nil
    end
  end

  defp parse_ticket_date(_), do: nil

  @doc """
  Calculates the total amount a participant owes on a ticket.
  Uses units_assigned to calculate the cost.
  """
  def calculate_participant_total(ticket_id, participant_name) do
    # Normalize name to lowercase for case-insensitive comparison
    participant_name = String.downcase(String.trim(participant_name))

    ticket = get_ticket_with_products!(ticket_id)
    total_participants = ticket.total_participants

    ticket.products
    |> Enum.reduce(Decimal.new("0"), fn product, acc ->
      # Calculate common share (from both is_common and common_units)
      common_cost = calculate_common_cost(product, total_participants)

      # Calculate personal assignment cost
      personal_cost = calculate_personal_cost(product, participant_name)

      Decimal.add(acc, Decimal.add(common_cost, personal_cost))
    end)
  end

  defp calculate_common_cost(product, total_participants) do
    # Legacy is_common support
    legacy_common =
      if product.is_common do
        Decimal.div(product.total_price, Decimal.new(total_participants))
      else
        Decimal.new("0")
      end

    # New common_units support
    common_units = product.common_units || Decimal.new("0")

    new_common =
      if Decimal.compare(common_units, Decimal.new("0")) == :gt do
        unit_cost = Decimal.div(product.total_price, Decimal.new(product.units))
        common_total_cost = Decimal.mult(unit_cost, common_units)
        Decimal.div(common_total_cost, Decimal.new(total_participants))
      else
        Decimal.new("0")
      end

    # Use whichever is greater (for backward compatibility during transition)
    if Decimal.compare(legacy_common, new_common) == :gt do
      legacy_common
    else
      new_common
    end
  end

  defp calculate_personal_cost(product, participant_name) do
    assignment =
      Enum.find(product.participant_assignments, fn pa ->
        pa.participant_name == participant_name
      end)

    if assignment do
      # Calculate based on units_assigned and percentage for shared groups
      # Each unit costs: total_price / total_units
      unit_cost = Decimal.div(product.total_price, Decimal.new(product.units))
      units = assignment.units_assigned || Decimal.new("0")
      share = Decimal.mult(unit_cost, units)

      # Apply percentage for shared groups
      percentage =
        Decimal.div(assignment.percentage || Decimal.new("100"), Decimal.new("100"))

      Decimal.mult(share, percentage)
    else
      Decimal.new("0")
    end
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
