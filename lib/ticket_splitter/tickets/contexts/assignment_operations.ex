defmodule TicketSplitter.Tickets.Contexts.AssignmentOperations do
  @moduledoc """
  Operations for ParticipantAssignment CRUD and assignment logic (groups, percentages, etc).
  """

  import Ecto.Query, warn: false
  alias TicketSplitter.Repo
  alias TicketSplitter.Tickets.{ParticipantAssignment, Product, ParticipantConfig}

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
    participant_name = String.trim(participant_name)

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
  Ensures a ParticipantConfig exists and increments total_participants if it's a new participant.
  """
  def create_participant_assignment(attrs \\ %{}) do
    # Ensure participant config exists and increment if new
    # This handles the case where someone assigns a product to a NEW participant in assign view
    if attrs[:participant_name] && attrs[:product_id] do
      # Get ticket_id from product
      product = TicketSplitter.Tickets.get_product!(attrs[:product_id])

      # Ensure config exists and increment total_participants if new participant
      TicketSplitter.Tickets.ensure_participant_and_update_total(
        product.ticket_id,
        attrs[:participant_name]
      )
    end

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
    participant_name = String.trim(participant_name)

    # Calculate available units (excluding assigned AND common units)
    # Use main context for cross-context call
    available = TicketSplitter.Tickets.get_available_units(product_id)

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
    participant_name = String.trim(participant_name)

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
    participant_name = String.trim(participant_name)

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
    participant_name = String.trim(participant_name)

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

  @doc """
  Updates a participant's name across all assignments and configs.
  """
  def update_participant_name(ticket_id, old_name, new_name) do
    old_name = String.trim(old_name)
    new_name = String.trim(new_name)

    # Validate new name is not empty
    if new_name == "" do
      {:error, :empty_name}
    else
      Repo.transaction(fn ->
        # Update all participant assignments
        assignment_count =
          from(pa in ParticipantAssignment,
            join: p in Product,
            on: pa.product_id == p.id,
            where: p.ticket_id == ^ticket_id and pa.participant_name == ^old_name
          )
          |> Repo.update_all(set: [participant_name: new_name])
          |> elem(0)

        # Update participant config if it exists
        from(pc in ParticipantConfig,
          where: pc.ticket_id == ^ticket_id and pc.participant_name == ^old_name
        )
        |> Repo.update_all(set: [participant_name: new_name])

        assignment_count
      end)
    end
  end

  @doc """
  Checks if a participant name exists in a ticket (has assignments).
  Returns true if the name exists, false otherwise.
  """
  def participant_name_exists?(ticket_id, participant_name) do
    participant_name = String.trim(participant_name)

    query =
      from pa in ParticipantAssignment,
        join: p in Product,
        on: pa.product_id == p.id,
        where: p.ticket_id == ^ticket_id and pa.participant_name == ^participant_name,
        limit: 1

    Repo.exists?(query)
  end

  @doc """
  Checks if a participant has any assignments in a ticket.
  Returns true if they have assignments, false otherwise.
  """
  def participant_has_assignments?(ticket_id, participant_name) do
    participant_name = String.trim(participant_name)
    participant_name_exists?(ticket_id, participant_name)
  end
end
