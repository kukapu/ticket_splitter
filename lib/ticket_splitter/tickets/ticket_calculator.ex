defmodule TicketSplitter.Tickets.TicketCalculator do
  @moduledoc """
  Calculations for ticket totals and participant splits.
  Extracted from TicketLive for better separation of concerns.
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
end
