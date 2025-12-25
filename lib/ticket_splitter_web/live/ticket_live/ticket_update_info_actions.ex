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
  """
  def calculate_min_participants(ticket_id) do
    real_participants_count = length(Tickets.get_ticket_participants(ticket_id))
    max(real_participants_count, 1)
  end
end
