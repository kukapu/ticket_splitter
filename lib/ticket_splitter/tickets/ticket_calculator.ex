defmodule TicketSplitter.Tickets.TicketCalculator do
  @moduledoc """
  Calculations for ticket totals and participant splits.
  Extracted from TicketLive and Tickets context for better separation of concerns.
  """

  alias TicketSplitter.Tickets

  @doc """
  Calculates the total of all products in a ticket.
  """
  def calculate_ticket_total(products) do
    Enum.reduce(products, Decimal.new("0"), fn product, acc ->
      Decimal.add(acc, product.total_price)
    end)
  end

  @doc """
  Calculates total assigned amount considering common and assigned units.
  Takes into account both legacy is_common and new common_units support.
  """
  def calculate_total_assigned(products, _total_participants) do
    Enum.reduce(products, Decimal.new("0"), fn product, acc ->
      # Legacy is_common support
      legacy_common_cost =
        if product.is_common do
          product.total_price
        else
          Decimal.new("0")
        end

      # New common_units support
      common_units = product.common_units || Decimal.new("0")

      common_units_cost =
        if Decimal.compare(common_units, Decimal.new("0")) == :gt do
          unit_cost = Decimal.div(product.total_price, Decimal.new(product.units))
          Decimal.mult(unit_cost, common_units)
        else
          Decimal.new("0")
        end

      # For non-common products, calculate based on assigned units
      # Get all unique assignment groups for this product
      assigned_groups_cost =
        product.participant_assignments
        |> Enum.group_by(fn pa -> pa.assignment_group_id end)
        |> Enum.map(fn {_group_id, assignments} ->
          # All assignments in a group share the same units
          units = hd(assignments).units_assigned || Decimal.new("0")
          # Calculate cost for these units
          unit_cost = Decimal.div(product.total_price, Decimal.new(product.units))
          Decimal.mult(unit_cost, units)
        end)
        |> Enum.reduce(Decimal.new("0"), fn group_cost, total ->
          Decimal.add(total, group_cost)
        end)

      # Sum all costs
      product_total =
        Decimal.add(legacy_common_cost, Decimal.add(common_units_cost, assigned_groups_cost))

      Decimal.add(acc, product_total)
    end)
  end

  @doc """
  Calculates total common cost across all products.
  Includes both legacy is_common and new common_units support.
  """
  def calculate_total_common(products) do
    Enum.reduce(products, Decimal.new("0"), fn product, acc ->
      # Legacy is_common support
      legacy_common_cost =
        if product.is_common do
          product.total_price
        else
          Decimal.new("0")
        end

      # New common_units support
      common_units = product.common_units || Decimal.new("0")

      common_units_cost =
        if Decimal.compare(common_units, Decimal.new("0")) == :gt do
          unit_cost = Decimal.div(product.total_price, Decimal.new(product.units))
          Decimal.mult(unit_cost, common_units)
        else
          Decimal.new("0")
        end

      # Sum common costs
      product_common_total = Decimal.add(legacy_common_cost, common_units_cost)
      Decimal.add(acc, product_common_total)
    end)
  end

  @doc """
  Calculates participant summary for the summary modal.
  Returns a map with name, color, total, and multiplier.
  """
  def calculate_participant_summary(ticket_id, participant) do
    total = Tickets.calculate_participant_total_with_multiplier(ticket_id, participant.name)
    multiplier = Tickets.get_participant_multiplier(ticket_id, participant.name)
    %{name: participant.name, color: participant.color, total: total, multiplier: multiplier}
  end

  @doc """
  Parses date from JSON format (YYYY-MM-DD string) to Date.
  Returns nil if the date is invalid or nil.
  """
  def parse_ticket_date(nil), do: nil

  def parse_ticket_date(date_string) when is_binary(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> date
      {:error, _} -> nil
    end
  end

  def parse_ticket_date(_), do: nil

  @doc """
  Calculates the common cost for a product divided among participants.
  Supports both legacy is_common and new common_units.
  Uses whichever is greater for backward compatibility.
  """
  def calculate_common_cost(product, total_participants) do
    # Avoid division by zero: use at least 1 participant
    safe_participants = max(total_participants, 1)

    # Legacy is_common support
    legacy_common =
      if product.is_common do
        Decimal.div(product.total_price, Decimal.new(safe_participants))
      else
        Decimal.new("0")
      end

    # New common_units support
    common_units = product.common_units || Decimal.new("0")

    new_common =
      if Decimal.compare(common_units, Decimal.new("0")) == :gt do
        unit_cost = Decimal.div(product.total_price, Decimal.new(product.units))
        common_total_cost = Decimal.mult(unit_cost, common_units)
        Decimal.div(common_total_cost, Decimal.new(safe_participants))
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

  @doc """
  Calculates the personal cost for a participant on a product.
  Returns 0 if the participant has no assignments.
  """
  def calculate_personal_cost(product, participant_name) do
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
  Calculates the common cost with multiplier support.
  Used when participants have different multipliers.
  """
  def calculate_common_cost_with_multiplier(product, effective_participants, multiplier) do
    # Avoid division by zero: use at least 1 participant
    safe_participants = max(effective_participants, 1)

    # Legacy is_common support
    legacy_common =
      if product.is_common do
        per_share = Decimal.div(product.total_price, Decimal.new(safe_participants))
        Decimal.mult(per_share, Decimal.new(multiplier))
      else
        Decimal.new("0")
      end

    # New common_units support
    common_units = product.common_units || Decimal.new("0")

    new_common =
      if Decimal.compare(common_units, Decimal.new("0")) == :gt do
        unit_cost = Decimal.div(product.total_price, Decimal.new(product.units))
        common_total_cost = Decimal.mult(unit_cost, common_units)
        per_share = Decimal.div(common_total_cost, Decimal.new(safe_participants))
        Decimal.mult(per_share, Decimal.new(multiplier))
      else
        Decimal.new("0")
      end

    # Use whichever is greater (for backward compatibility)
    if Decimal.compare(legacy_common, new_common) == :gt do
      legacy_common
    else
      new_common
    end
  end
end
