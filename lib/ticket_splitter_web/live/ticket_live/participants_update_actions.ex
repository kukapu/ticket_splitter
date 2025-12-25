defmodule TicketSplitterWeb.TicketLive.ParticipantsUpdateActions do
  @moduledoc """
  Módulo que contiene funciones para actualizar el conteo de participantes.
  """

  alias TicketSplitter.Tickets.TicketBroadcaster

  @doc """
  Ejecuta la actualización del ticket y broadcast el update.
  """
  def execute_update_and_broadcast(ticket, new_count) do
    case TicketSplitter.Tickets.update_ticket(ticket, %{total_participants: new_count}) do
      {:ok, updated_ticket} ->
        TicketBroadcaster.broadcast_ticket_update(updated_ticket.id)
        {:ok, updated_ticket}

      {:error, _} ->
        :error
    end
  end

  @doc """
  Construye assigns para actualizar el resumen modal cuando está abierto.
  """
  def build_summary_modal_assigns(products, new_count, ticket_id, participants, updated_ticket) do
    {total_ticket, total_assigned, pending} =
      TicketSplitterWeb.TicketLive.CalculationActions.calculate_summary_totals(products, new_count)

    participant_summaries =
      TicketSplitterWeb.TicketLive.CalculationActions.calculate_participant_summaries(ticket_id, participants)

    [
      ticket: updated_ticket,
      participants_for_summary: participant_summaries,
      total_ticket_for_summary: total_ticket,
      total_assigned_for_summary: total_assigned,
      pending_for_summary: pending
    ]
  end

  @doc """
  Construye assigns básicos cuando no está abierto el modal de resumen.
  """
  def build_basic_assigns(ticket) do
    [ticket: ticket]
  end
end
