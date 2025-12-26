defmodule TicketSplitterWeb.TicketLive.TicketUpdateInfoActions do
  @moduledoc """
  Módulo que contiene funciones para manejar actualizaciones de tickets vía handle_info.
  """

  alias TicketSplitter.Tickets
  alias TicketSplitterWeb.TicketLive.CalculationActions

  @doc """
  Determina si se deben actualizar los datos del resumen modal.
  """
  def should_update_summary?(show_summary_modal) do
    show_summary_modal
  end

  @doc """
  Calcula los assigns para cuando el resumen modal está abierto.
  """
  def build_summary_assigns(ticket_id, ticket, current_participant_name, participants) do
    {total_ticket, total_assigned, pending} =
      CalculationActions.calculate_summary_totals(ticket.products, ticket.total_participants)

    {sorted_summaries, _} =
      CalculationActions.calculate_summary_data(
        ticket_id,
        participants,
        ticket.products,
        ticket.total_participants,
        current_participant_name,
        pending,
        "Rest of participants"
      )

    [
      ticket: ticket,
      products: ticket.products,
      participants_for_summary: sorted_summaries,
      total_ticket_for_summary: total_ticket,
      total_assigned_for_summary: total_assigned,
      pending_for_summary: pending
    ]
  end

  @doc """
  Calcula los assigns básicos para cuando no está abierto el resumen.
  """
  def build_basic_assigns(ticket) do
    [
      ticket: ticket,
      products: ticket.products
    ]
  end

  @doc """
  Calcula el min_participants basado en el ticket_id.
  Es el máximo entre:
  - Número de participantes activos
  - Suma de multiplicadores de todos los participantes activos
  """
  def calculate_min_participants(ticket_id) do
    active_participants = Tickets.get_ticket_participants(ticket_id)
    configs = Tickets.list_participant_configs(ticket_id)

    # Suma de multiplicadores de participantes activos (default 1 si no tienen config)
    sum_multipliers =
      Enum.reduce(active_participants, 0, fn participant, acc ->
        multiplier =
          Enum.find_value(configs, 1, fn config ->
            if config.participant_name == participant.name, do: config.multiplier, else: nil
          end)

        acc + multiplier
      end)

    # El mínimo es la suma de multiplicadores, o 1 si no hay participantes
    max(sum_multipliers, 1)
  end
end
