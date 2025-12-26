defmodule TicketSplitterWeb.TicketLive.CalculationActions do
  @moduledoc """
  Módulo que contiene funciones puras para calcular resúmenes de participantes y totales.
  """

  alias TicketSplitter.Tickets.TicketCalculator

  @doc """
  Ordena los resúmenes de participantes para que el usuario actual esté primero.
  """
  def sort_participant_summaries(summaries, current_participant_name) do
    Enum.sort_by(summaries, fn summary ->
      if summary.name == current_participant_name do
        {0, summary.name}
      else
        {1, summary.name}
      end
    end)
  end

  @doc """
  Calcula el resumen de todos los participantes.
  """
  def calculate_participant_summaries(ticket_id, participants) do
    Enum.map(participants, fn participant ->
      TicketCalculator.calculate_participant_summary(ticket_id, participant)
    end)
  end

  @doc """
  Calcula los datos necesarios para el resumen (totales y pendiente).
  """
  def calculate_summary_totals(products, total_participants) do
    total_ticket = TicketCalculator.calculate_ticket_total(products)
    total_assigned = TicketCalculator.calculate_total_assigned(products, total_participants)
    pending = Decimal.sub(total_ticket, total_assigned)

    {total_ticket, total_assigned, pending}
  end

  @doc """
  Calcula la suma de los multiplicadores activos.
  """
  def calculate_active_multipliers_sum(summaries) do
    Enum.reduce(summaries, 0, fn summary, acc ->
      acc + (summary.multiplier || 1)
    end)
  end

  @doc """
  Añade el resumen de "Rest of participants" si es necesario.
  """
  def maybe_add_rest_summary(
        summaries,
        products,
        total_participants,
        active_multipliers_sum,
        pending,
        rest_label
      ) do
    if total_participants > active_multipliers_sum do
      rest_count = total_participants - active_multipliers_sum

      total_common = TicketCalculator.calculate_total_common(products)

      rest_common_share =
        if total_participants > 0 do
          share_per_person = Decimal.div(total_common, Decimal.new(total_participants))
          Decimal.mult(share_per_person, Decimal.new(rest_count))
        else
          Decimal.new("0")
        end

      rest_total = Decimal.add(rest_common_share, pending)

      rest_individual_total =
        if rest_count > 0 do
          Decimal.div(rest_total, Decimal.new(rest_count))
        else
          Decimal.new("0")
        end

      rest_summary = %{
        name: "#{rest_label} (#{rest_count}x)",
        color: "#94a3b8",
        total: rest_individual_total,
        multiplier: 1,
        is_rest: true
      }

      summaries ++ [rest_summary]
    else
      summaries
    end
  end

  @doc """
  Calcula los datos completos del resumen para el modal.
  """
  def calculate_summary_data(
        ticket_id,
        participants,
        products,
        total_participants,
        current_participant_name,
        pending,
        rest_label
      ) do
    participant_summaries = calculate_participant_summaries(ticket_id, participants)
    sorted_summaries = sort_participant_summaries(participant_summaries, current_participant_name)

    active_multipliers_sum = calculate_active_multipliers_sum(sorted_summaries)

    final_summaries =
      maybe_add_rest_summary(
        sorted_summaries,
        products,
        total_participants,
        active_multipliers_sum,
        pending,
        rest_label
      )

    {final_summaries, active_multipliers_sum}
  end
end
